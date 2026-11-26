"""Local unit tests for Equipment Loans Lambda handler using an in-memory DynamoDB mock."""

from __future__ import annotations

import json
import unittest
from typing import Any

from src.lambda_function import lambda_handler


class _FakeDynamoTable:
    """Minimal in-memory mock of boto3 DynamoDB Table for offline verification."""

    table_status = "ACTIVE"

    def __init__(self) -> None:
        self._items: dict[str, dict[str, Any]] = {}

    def put_item(self, Item: dict[str, Any]) -> dict[str, Any]:
        self._items[Item["loan_id"]] = dict(Item)
        return {"ResponseMetadata": {"HTTPStatusCode": 200}}

    def scan(self) -> dict[str, Any]:
        return {"Items": list(self._items.values())}

    def get_item(self, Key: dict[str, str]) -> dict[str, Any]:
        item = self._items.get(Key["loan_id"])
        return {"Item": dict(item)} if item else {}

    def update_item(
        self,
        Key: dict[str, str],
        UpdateExpression: str,
        ExpressionAttributeNames: dict[str, str],
        ExpressionAttributeValues: dict[str, Any],
        ReturnValues: str = "ALL_NEW",
    ) -> dict[str, Any]:
        item = self._items[Key["loan_id"]]
        for placeholder, attr_name in ExpressionAttributeNames.items():
            val_key = ":" + placeholder.lstrip("#")
            item[attr_name] = ExpressionAttributeValues[val_key]
        return {"Attributes": dict(item)}

    def delete_item(self, Key: dict[str, str]) -> dict[str, Any]:
        self._items.pop(Key["loan_id"], None)
        return {"ResponseMetadata": {"HTTPStatusCode": 200}}


def _make_event(method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    event: dict[str, Any] = {
        "rawPath": path,
        "requestContext": {"http": {"method": method}},
    }
    if body is not None:
        event["body"] = json.dumps(body)
    return event


class TestEquipmentLoansAPI(unittest.TestCase):
    def setUp(self) -> None:
        self.table = _FakeDynamoTable()

    def test_health_check(self) -> None:
        res = lambda_handler(_make_event("GET", "/health"), table_override=self.table)
        self.assertEqual(res["statusCode"], 200)
        body = json.loads(res["body"])
        self.assertEqual(body["status"], "ok")
        self.assertEqual(body["table_status"], "ACTIVE")

    def test_full_crud_lifecycle(self) -> None:
        # 1. CREATE
        create_res = lambda_handler(
            _make_event(
                "POST",
                "/loans",
                {
                    "borrower_name": "Budi Santoso",
                    "borrower_id": "220123456",
                    "equipment_name": "Oscilloscope Rigol DS1054Z",
                    "quantity": 1,
                    "due_date": "2026-12-03",
                },
            ),
            table_override=self.table,
        )
        self.assertEqual(create_res["statusCode"], 201)
        created = json.loads(create_res["body"])["item"]
        loan_id = created["loan_id"]
        self.assertEqual(created["status"], "BORROWED")

        # 2. READ (List & Detail)
        list_res = lambda_handler(_make_event("GET", "/loans"), table_override=self.table)
        self.assertEqual(list_res["statusCode"], 200)
        self.assertEqual(json.loads(list_res["body"])["count"], 1)

        get_res = lambda_handler(_make_event("GET", f"/loans/{loan_id}"), table_override=self.table)
        self.assertEqual(get_res["statusCode"], 200)
        self.assertEqual(json.loads(get_res["body"])["item"]["borrower_name"], "Budi Santoso")

        # 3. UPDATE
        update_res = lambda_handler(
            _make_event("PUT", f"/loans/{loan_id}", {"status": "RETURNED"}),
            table_override=self.table,
        )
        self.assertEqual(update_res["statusCode"], 200)
        updated = json.loads(update_res["body"])["item"]
        self.assertEqual(updated["status"], "RETURNED")
        self.assertIn("returned_at", updated)

        # 4. DELETE
        delete_res = lambda_handler(_make_event("DELETE", f"/loans/{loan_id}"), table_override=self.table)
        self.assertEqual(delete_res["statusCode"], 200)

        after_delete = lambda_handler(_make_event("GET", f"/loans/{loan_id}"), table_override=self.table)
        self.assertEqual(after_delete["statusCode"], 404)

    def test_create_validation_error(self) -> None:
        res = lambda_handler(
            _make_event("POST", "/loans", {"borrower_name": "Ani"}),
            table_override=self.table,
        )
        self.assertEqual(res["statusCode"], 400)


if __name__ == "__main__":
    unittest.main()
