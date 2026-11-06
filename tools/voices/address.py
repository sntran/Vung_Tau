"""The forms of address (plan 0007, R6 to R11), for the voices build.

This is the same as scripts/address.gd in the game. tests/unit/address_cases.json
checks both. The rules are in data/address.json.
"""

import unicodedata

FIELDS = ["you", "me", "them", "self"]
MAX_DEPTH = 8


def rule_for(data: dict, person_id: str, traveler: dict) -> dict:
    """The first rule that agrees with the person and the traveler, or {}."""
    person = data.get("people", {}).get(person_id, {})
    person_age = int(person.get("age", 0))
    traveler_age = int(traveler.get("age", 30))
    difference = person_age - traveler_age
    for rule in data.get("rules", []):
        if "person" in rule and rule["person"] != person_id:
            continue
        if "role" in rule and rule["role"] != person.get("role", ""):
            continue
        if "min" in rule and difference < int(rule["min"]):
            continue
        if "max" in rule and difference > int(rule["max"]):
            continue
        if "min_person_age" in rule and person_age < int(rule["min_person_age"]):
            continue
        if "max_person_age" in rule and person_age > int(rule["max_person_age"]):
            continue
        if "min_traveler_age" in rule and traveler_age < int(rule["min_traveler_age"]):
            continue
        if "max_traveler_age" in rule and traveler_age > int(rule["max_traveler_age"]):
            continue
        return rule
    return {}


def word(data: dict, value: str, person: dict, traveler: dict) -> str:
    """A word, or the word of a class of "classes" (by gender or region); a person can replace a class."""
    classes = data.get("classes", {})
    result = value
    for _ in range(MAX_DEPTH):
        if result not in classes:
            return result
        if result in person:
            result = str(person[result])
            continue
        word_class = classes[result]
        by = word_class.get("by", "")
        if by == "person_gender":
            result = str(word_class.get(person.get("gender", "male"), ""))
        elif by == "person_region":
            result = str(word_class.get(person.get("region", "south"), ""))
        elif by == "traveler_gender":
            result = str(word_class.get(traveler.get("gender", "male"), ""))
        elif by == "person":
            result = str(person.get(word_class.get("field", ""), ""))
        else:
            return ""
    return result


def words(data: dict, person_id: str, traveler: dict) -> dict:
    person = data.get("people", {}).get(person_id, {})
    rule = rule_for(data, person_id, traveler)
    return {field: word(data, str(rule.get(field, "")), person, traveler) for field in FIELDS}


def capital(value: str) -> str:
    return value[:1].upper() + value[1:]


def fill(text: str, resolved: dict) -> str:
    for field in FIELDS:
        value = resolved.get(field, "")
        text = text.replace("{%s}" % field, value).replace("{%s}" % field.capitalize(), capital(value))
    return text


def fill_english(data: dict, text: str, resolved: dict) -> str:
    dear = data.get("dear", {})
    if resolved.get("you", "") in dear.get("words", []):
        return text.replace("{dear}", dear.get("text", "dear"))
    return text.replace(", {dear}", "").replace(" {dear}", "").replace("{dear}", "")


def display_name(data: dict, person_id: str, traveler: dict) -> str:
    person = data.get("people", {}).get(person_id)
    if not person:
        return ""
    them = words(data, person_id, traveler)["them"]
    if not them or them in data.get("display_name", {}).get("keep_name", []):
        return person.get("name", "")
    return f"{capital(them)} {person.get('given', '')}"


def fields_in(texts: list) -> list[str]:
    return [f for f in FIELDS if any(("{%s}" % f) in str(t) or ("{%s}" % f.capitalize()) in str(t) for t in texts)]


def line_fields(line: dict) -> list[str]:
    """The fields that the voice of a line (or a reply) depends on: its texts and the conditions of its variants."""
    texts = [line.get("vi", ""), line.get("say", "")]
    when = set()
    for variant in line.get("variants", []):
        texts += [variant.get("vi", ""), variant.get("say", "")]
        when.update(variant.get("when", {}))
    used = set(fields_in(texts)) | when
    return [f for f in FIELDS if f in used]


def ascii_text(text: str) -> str:
    text = text.replace("đ", "d").replace("Đ", "D")
    return "".join(c for c in unicodedata.normalize("NFD", text) if not unicodedata.combining(c))


def key(resolved: dict, fields: list[str]) -> str:
    return "-".join(ascii_text(resolved.get(f, "")) for f in fields)


def resolve_line(data: dict, line: dict, resolved: dict) -> dict:
    result = {k: v for k, v in line.items() if k != "variants"}
    for variant in line.get("variants", []):
        if all(resolved.get(f, "") == v for f, v in variant.get("when", {}).items()):
            for text_key in ("vi", "say", "en"):
                if text_key in variant:
                    result[text_key] = variant[text_key]
            if "vi" in variant and "say" not in variant:
                result.pop("say", None)
            break
    for text_key in ("vi", "say", "text"):
        if text_key in result:
            result[text_key] = fill(result[text_key], resolved)
    if "en" in result:
        result["en"] = fill_english(data, result["en"], resolved)
    return result


def all_words(data: dict, person_id: str) -> list[dict]:
    """All the different words for the person, for each gender and age of the traveler, in a fixed order."""
    limits = data.get("traveler", {})
    result, seen = [], set()
    for gender in ("male", "female"):
        for age in range(int(limits.get("min_age", 18)), int(limits.get("max_age", 80)) + 1):
            resolved = words(data, person_id, {"gender": gender, "age": age})
            ident = tuple(resolved[f] for f in FIELDS)
            if ident not in seen:
                seen.add(ident)
                result.append(resolved)
    return result
