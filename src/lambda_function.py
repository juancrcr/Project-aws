"""AWS Lambda handler for the Equipment Loans CRUD API (Track C: Serverless)."""

from __future__ import annotations

import json
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

try:
    import boto3
    from botocore.exceptions import BotoCoreError, ClientError
except ImportError:  # Allows running offline unit tests without boto3 installed locally
    boto3 = None  # type: ignore[assignment]
    BotoCoreError = Exception  # type: ignore[misc,assignment]
    ClientError = Exception  # type: ignore[misc,assignment]

TABLE_NAME = os.environ.get("TABLE_NAME", "equipment-loans")
VALID_STATUSES = {"BORROWED", "RETURNED"}
REQUIRED_CREATE_FIELDS = (
    "borrower_name",
    "borrower_id",
    "equipment_name",
    "quantity",
    "due_date",
)

_dynamodb_resource = None


def _get_table(table_override: Any = None) -> Any:
    """Return the DynamoDB Table resource, allowing injection for local tests."""
    if table_override is not None:
        return table_override
    global _dynamodb_resource
    if boto3 is None:
        raise RuntimeError("boto3 is required when running against AWS DynamoDB")
    if _dynamodb_resource is None:
        _dynamodb_resource = boto3.resource("dynamodb")
    return _dynamodb_resource.Table(TABLE_NAME)


class _DecimalEncoder(json.JSONEncoder):
    """Serialize DynamoDB Decimal values as int or float."""

    def default(self, obj: Any) -> Any:
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def _response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    """Build an API Gateway HTTP API (v2.0) compatible JSON response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, cls=_DecimalEncoder),
    }


def _parse_body(event: dict[str, Any]) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    """Parse JSON request body; returns (data, error_response)."""
    raw_body = event.get("body")
    if not raw_body:
        return None, _response(400, {"error": "Request body is required"})
    if isinstance(raw_body, dict):
        return raw_body, None
    try:
        parsed = json.loads(raw_body)
    except json.JSONDecodeError:
        return None, _response(400, {"error": "Invalid JSON in request body"})
    if not isinstance(parsed, dict):
        return None, _response(400, {"error": "Request body must be a JSON object"})
    return parsed, None


def _extract_route(event: dict[str, Any]) -> tuple[str, str]:
    """Extract HTTP method and normalized path from API Gateway v1 or v2 events."""
    req_ctx = event.get("requestContext", {})
    http_ctx = req_ctx.get("http", {})
    method = (http_ctx.get("method") or event.get("httpMethod") or "GET").upper()
    path = event.get("rawPath") or event.get("path") or "/"
    return method, path.rstrip("/") or "/"


def _ensure_table_exists(table: Any) -> str:
    """Return table status, auto-creating the DynamoDB table if missing (useful in Vocareum labs)."""
    try:
        return str(table.table_status)
    except ClientError as exc:
        err_code = exc.response.get("Error", {}).get("Code", "")
        if err_code != "ResourceNotFoundException" or boto3 is None:
            raise
        created = boto3.resource("dynamodb").create_table(
            TableName=TABLE_NAME,
            AttributeDefinitions=[{"AttributeName": "loan_id", "AttributeType": "S"}],
            KeySchema=[{"AttributeName": "loan_id", "KeyType": "HASH"}],
            BillingMode="PAY_PER_REQUEST",
        )
        created.wait_until_exists()
        return str(created.table_status)


def _handle_health(table: Any) -> dict[str, Any]:
    """Verify Lambda execution and DynamoDB table connectivity (auto-creates table if needed)."""
    try:
        status = _ensure_table_exists(table)
    except (BotoCoreError, ClientError) as exc:
        return _response(503, {"status": "unhealthy", "table": TABLE_NAME, "detail": str(exc)})
    return _response(200, {"status": "ok", "table": TABLE_NAME, "table_status": status})


def _handle_create_loan(event: dict[str, Any], table: Any) -> dict[str, Any]:
    """Create a new EquipmentLoan record."""
    data, err = _parse_body(event)
    if err:
        return err

    missing = [f for f in REQUIRED_CREATE_FIELDS if data.get(f) in (None, "")]
    if missing:
        return _response(400, {"error": f"Missing required fields: {', '.join(missing)}"})

    try:
        quantity = int(data["quantity"])
    except (TypeError, ValueError):
        return _response(400, {"error": "quantity must be an integer"})
    if quantity < 1:
        return _response(400, {"error": "quantity must be at least 1"})

    item = {
        "loan_id": str(uuid.uuid4()),
        "borrower_name": str(data["borrower_name"]).strip(),
        "borrower_id": str(data["borrower_id"]).strip(),
        "equipment_name": str(data["equipment_name"]).strip(),
        "quantity": quantity,
        "status": "BORROWED",
        "borrowed_at": datetime.now(timezone.utc).isoformat(),
        "due_date": str(data["due_date"]).strip(),
    }
    table.put_item(Item=item)
    return _response(201, {"message": "Loan created", "item": item})


def _handle_list_loans(table: Any) -> dict[str, Any]:
    """Return all EquipmentLoan records."""
    result = table.scan()
    items = result.get("Items", [])
    return _response(200, {"count": len(items), "items": items})


def _handle_get_loan(loan_id: str, table: Any) -> dict[str, Any]:
    """Return a single EquipmentLoan record by loan_id."""
    result = table.get_item(Key={"loan_id": loan_id})
    item = result.get("Item")
    if not item:
        return _response(404, {"error": "Loan not found", "loan_id": loan_id})
    return _response(200, {"item": item})


def _handle_update_loan(loan_id: str, event: dict[str, Any], table: Any) -> dict[str, Any]:
    """Update status, due_date, or quantity of an existing EquipmentLoan."""
    data, err = _parse_body(event)
    if err:
        return err

    existing = table.get_item(Key={"loan_id": loan_id}).get("Item")
    if not existing:
        return _response(404, {"error": "Loan not found", "loan_id": loan_id})

    updates: dict[str, Any] = {}
    if "status" in data:
        new_status = str(data["status"]).upper().strip()
        if new_status not in VALID_STATUSES:
            return _response(400, {"error": f"status must be one of {sorted(VALID_STATUSES)}"})
        updates["status"] = new_status
        if new_status == "RETURNED" and not existing.get("returned_at"):
            updates["returned_at"] = datetime.now(timezone.utc).isoformat()

    if "due_date" in data and data["due_date"]:
        updates["due_date"] = str(data["due_date"]).strip()

    if "quantity" in data:
        try:
            qty = int(data["quantity"])
        except (TypeError, ValueError):
            return _response(400, {"error": "quantity must be an integer"})
        if qty < 1:
            return _response(400, {"error": "quantity must be at least 1"})
        updates["quantity"] = qty

    if not updates:
        return _response(400, {"error": "No valid updatable fields provided (status, due_date, quantity)"})

    expr_parts = [f"#{k} = :{k}" for k in updates]
    expr_names = {f"#{k}": k for k in updates}
    expr_values = {f":{k}": v for k, v in updates.items()}

    result = table.update_item(
        Key={"loan_id": loan_id},
        UpdateExpression="SET " + ", ".join(expr_parts),
        ExpressionAttributeNames=expr_names,
        ExpressionAttributeValues=expr_values,
        ReturnValues="ALL_NEW",
    )
    return _response(200, {"message": "Loan updated", "item": result.get("Attributes")})


def _handle_delete_loan(loan_id: str, table: Any) -> dict[str, Any]:
    """Delete an EquipmentLoan record by loan_id."""
    existing = table.get_item(Key={"loan_id": loan_id}).get("Item")
    if not existing:
        return _response(404, {"error": "Loan not found", "loan_id": loan_id})
    table.delete_item(Key={"loan_id": loan_id})
    return _response(200, {"message": "Loan deleted", "loan_id": loan_id})


def lambda_handler(event: dict[str, Any], context: Any = None, table_override: Any = None) -> dict[str, Any]:
    """Main AWS Lambda entry point for /health and /loans CRUD routes."""
    method, path = _extract_route(event or {})
    table = _get_table(table_override)

    try:
        if method == "GET" and path == "/health":
            return _handle_health(table)

        if path == "/loans":
            if method == "POST":
                return _handle_create_loan(event, table)
            if method == "GET":
                return _handle_list_loans(table)

        if path.startswith("/loans/"):
            loan_id = path.split("/", 2)[2].strip()
            if not loan_id:
                return _response(400, {"error": "loan_id is required"})
            if method == "GET":
                return _handle_get_loan(loan_id, table)
            if method == "PUT":
                return _handle_update_loan(loan_id, event, table)
            if method == "DELETE":
                return _handle_delete_loan(loan_id, table)

        return _response(404, {"error": f"Route not found: {method} {path}"})
    except (BotoCoreError, ClientError) as exc:
        return _response(500, {"error": "DynamoDB operation failed", "detail": str(exc)})
