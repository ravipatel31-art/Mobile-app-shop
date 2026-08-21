"""Server-side pricing. The client's total is never trusted: every order line
is recomputed from the current menu item and its selected options.

All money values are integers in minor currency units (e.g. paise/cents).

`selected` is a list of {"group": str, "label": str}. A group marked `multi`
may appear more than once; a required group must appear at least once.
"""
from .util import ApiError


def compute_line(item, selected, qty):
    """Return (unit_price, line_total, normalized_selection) for one line."""
    if qty is None or int(qty) < 1:
        raise ApiError("qty must be >= 1")
    qty = int(qty)

    groups = {g["group"]: g for g in item.get("options", [])}
    chosen = {}
    delta = 0

    for sel in selected or []:
        g = sel.get("group")
        label = sel.get("label")
        if g not in groups:
            raise ApiError(f"Unknown option group '{g}'")
        choice = next((c for c in groups[g]["choices"] if c["label"] == label), None)
        if choice is None:
            raise ApiError(f"Unknown choice '{label}' for '{g}'")
        chosen.setdefault(g, []).append(label)
        delta += int(choice.get("price_delta", 0))

    for g in item.get("options", []):
        name = g["group"]
        picked = chosen.get(name, [])
        if g.get("required") and not picked:
            raise ApiError(f"Option '{name}' is required")
        if not g.get("multi", False) and len(picked) > 1:
            raise ApiError(f"Only one '{name}' may be selected")

    unit = int(item["base_price"]) + delta
    return unit, unit * qty, list(selected or [])


def price_order(items_in, menu_lookup):
    """Validate and price a whole order.

    items_in: list of {item_id, qty, selected_options}
    menu_lookup: callable(item_id) -> menu item dict or None

    Returns (lines, total) where each line is a snapshot stored on the order.
    """
    if not items_in:
        raise ApiError("Order must contain at least one item")

    lines = []
    total = 0
    for entry in items_in:
        item = menu_lookup(entry.get("item_id"))
        if item is None:
            raise ApiError(f"Menu item '{entry.get('item_id')}' not found", 404)
        if not item.get("available", True):
            raise ApiError(f"'{item['name']}' is currently unavailable", 409)

        unit, line_total, selection = compute_line(
            item, entry.get("selected_options", []), entry.get("qty", 1)
        )
        lines.append(
            {
                "item_id": item["id"],
                "name": item["name"],
                "category": item.get("category", "other"),
                "qty": int(entry.get("qty", 1)),
                "unit_price": unit,
                "selected_options": selection,
                "line_total": line_total,
            }
        )
        total += line_total

    return lines, total
