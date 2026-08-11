import pandas as pd

INPUT = "data/bitkiler.csv"
OUTPUT = "data/bitkiler_by_disease.csv"

DISEASE_MAP = {
    "acne": "Acne",
    "eczema": "Eczema",
    "fungal": "Mantar",
    "fungus": "Mantar",
    "nail fungus": "Nail Fungus",
    "rosacea": "Rosacea",
    "vitiligo": "Vitiligo",
    "hair loss": "Hairloss",
    "hair": "Hairloss",
    "alopecia": "Hairloss",
    "sensitive": "Eczema",
    "inflammation": "Eczema",
    "allergy": "Alerji"
}

def infer_role_and_safety(text):
    text = str(text).lower()
    if "toxic" in text or "poison" in text:
        return "avoid", "dangerous"
    if "irrit" in text or "strong" in text:
        return "primary", "caution"
    if "sooth" in text or "calm" in text:
        return "primary", "safe"
    if "anti" in text:
        return "primary", "safe"
    return "support", "safe"

df = pd.read_csv(INPUT)

rows = []

for _, row in df.iterrows():
    uses = str(row["recommended_for"]).lower()

    for key, disease in DISEASE_MAP.items():
        if key in uses:
            role, safety = infer_role_and_safety(row["notes_cautions"])

            rows.append({
                "plant": row["common_name"],
                "scientific_name": row["scientific_name"],
                "disease": disease,
                "role": role,
                "safety": safety,
                "notes": row["notes_cautions"]
            })

new_df = pd.DataFrame(rows).drop_duplicates()

new_df.to_csv(OUTPUT, index=False)

print("✅ Dönüştürme tamamlandı")
print("📄 Çıktı:", OUTPUT)
print(new_df.head())
