import os
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from PIL import Image, ImageFilter, ImageOps, ImageEnhance
import cv2  
import pytesseract
import re
import numpy as np
import tensorflow as tf
from keras.layers import TFSMLayer
import csv
import json

# DOSYA VE KLASÖR YOLLARI
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
FRONTEND_DIR = os.path.join(os.path.dirname(BACKEND_DIR), 'frontend')

print(f"📂 Backend Yolu: {BACKEND_DIR}")
print(f"📂 Frontend Yolu: {FRONTEND_DIR}")

# Tek bir Flask instance'ı oluşturuyoruz ve tüm static klasörleri doğru bağlıyoruz
app = Flask(__name__, static_folder=FRONTEND_DIR, static_url_path='')
CORS(app, resources={r"/*": {"origins": "*"}})

# 1. ADIM: Hugging Face "Not Found" Hatası Çözümü (Kök Dizin)
@app.route('/')
def home():
    # Eğer frontend klasöründe index.html varsa onu döner, yoksa JSON mesajı verir
    if os.path.exists(os.path.join(FRONTEND_DIR, 'index.html')):
        return send_from_directory(FRONTEND_DIR, 'index.html')
    return jsonify({
        "status": "success",
        "message": "Bitkisel API ve Model başarıyla çalışıyor!",
        "endpoints": {"analyze": "/analyze (POST)"}
    })

# 2. ADIM: Resimlerin doğru klasörden servis edilmesi
@app.route('/img/<path:filename>')
def serve_images(filename):
    img_dir = os.path.join(BACKEND_DIR, 'img') # Kodun bulunduğu yerdeki img klasörü
    if not os.path.exists(img_dir):
        img_dir = os.path.join('/code', 'img') # Hugging Face Docker fallback
    return send_from_directory(img_dir, filename)

# REFERANS ARALIKLARI
REFERANS_ARALIKLARI = {
    "Ferritin": {"min": 15, "max": 150, "hedef": "Hairloss", "hedef_yuksek": "Rosacea"}, 
    "B12": {"min": 200, "max": 900, "hedef": "Hairloss", "hedef_yuksek": "Acne"},       
    "D_Vit": {"min": 30, "max": 100, "hedef": "Eczema", "hedef_yuksek": "Healthy"},     
    "Zinc": {"min": 70, "max": 120, "hedef": "Acne", "hedef_yuksek": "Healthy"},
    "Glukoz": {"min": 70, "max": 110, "hedef": "Mantar", "hedef_yuksek": "Mantar"},     
    "IgE": {"min": 0, "max": 100, "hedef": "Alerji", "hedef_yuksek": "Alerji"}          
}

# MODEL VE VERİ YÜKLEME
classes = ["Acne", "Alerji", "Benign", "Eczema", "Hairloss",
           "Healthy", "Mantar", "Nail Fungus", "Rosacea", "Vitiligo"]
IMG_SIZE = (224, 224)

try:
    model_path = os.path.join(BACKEND_DIR, "model", "skin_model_PRODUCTION")
    model = TFSMLayer(model_path, call_endpoint="serving_default")
    print("✅ Model yüklendi")
except Exception as e:
    model = None
    print(f"❌ Model yüklenemedi: {e}")

disease_herbs = {}
try:
    csv_path = os.path.join(BACKEND_DIR, "data", "bitkiler_by_disease.csv")
    with open(csv_path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            disease_herbs.setdefault(row["disease"], []).append(row)
except Exception as e:
    print(f"❌ CSV Yüklenemedi: {e}")


# YARDIMCI FONKSİYON: KAN ANALİZİ MANTIĞI
def analyze_blood_logic(data):
    bulgular = []
    hastaliklar = set()
    for key, val in data.items():
        if key in REFERANS_ARALIKLARI and val is not None and val != "":
            ref = REFERANS_ARALIKLARI[key]
            try:
                val = float(val)
                if val < ref["min"]:
                    bulgular.append({"parametre": key, "durum": f"Düşük ({val})"})
                    hastaliklar.add(ref["hedef"])
                elif val > ref["max"]:
                    bulgular.append({"parametre": key, "durum": f"Yüksek ({val})"})
                    # Güvenli kontrol: hedef_yuksek var mı ve Healthy değil mi?
                    if ref.get("hedef_yuksek") and ref["hedef_yuksek"] != "Healthy":
                        hastaliklar.add(ref["hedef_yuksek"])
            except:
                continue
                
    herbs = []
    for h in hastaliklar:
        herbs.extend(disease_herbs.get(h, []))
    
    baslik = "Değerler Normal"
    if bulgular:
        riskler = list(hastaliklar)
        baslik = f"Risk Analizi: {', '.join(riskler)}" if riskler else "Bazı Değerler Sınır Dışı"
    
    return {
        "type": "blood_result", 
        "bulgular": bulgular, 
        "prediction": baslik, 
        "herbs": herbs, 
        "hastaliklar": list(hastaliklar)
    }

# GELİŞMİŞ OCR FONKSİYONU
@app.route("/analyze/scan_blood_image", methods=["POST"])
def scan_blood_image():
    images = request.files.getlist("image")
    if not images:
        return jsonify({"error": "Resim yok"}), 400

    results = {}
    TARGETS = {
        "Ferritin": r"ferr[iı]t[iı]n",
        "B12": r"(?:v[iı]tam[iı]n\s)?[b8][\-\s]?[1ilı]2", 
        "D_Vit": r"(?:25[\-\s]?oh|d[ \-]?v[iı]t|v[iı]tam[iı]n\sd)",
        "Zinc": r"(?:ç[iı]nko|z[iı]nc)",
        "Glukoz": r"(?:glukoz|glucose|şeker|seker)",
        "IgE": r"(?:total\s[iı]ge|ig\s?e)"
    }

    for image_file in images:
        file_bytes = np.frombuffer(image_file.read(), np.uint8)
        img = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)
        if img is None: continue

        # 1. Resmi 2 kat büyüt (Netlik için)
        img = cv2.resize(img, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)

       # 2. Akıllı Görüntü Ön İşleme
        b, g, r_channel = cv2.split(img)
        if np.mean(r_channel) > 120 and np.mean(g) < 80: 
            _, thresh = cv2.threshold(r_channel, 150, 255, cv2.THRESH_BINARY)
            
            # Karakterlerin birbirine yapışmasını önlemek için kernel boyutunu 1x1'de tutup erozyon uyguluyoruz
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 1))
            thresh = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        else: # Normal beyaz kağıt tahlil
            thresh = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            thresh = cv2.threshold(thresh, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]

        # GÜNCELLEME: --psm 6 yerine tablolardaki dağınık sayıları çok daha iyi çözen --psm 11 (Sparse Text) modunu kullanıyoruz
        custom_config = r'--oem 3 --psm 11 -c tessedit_char_whitelist=abcdefghijklmnopqrstuvwxyzıüşöçğABCDEFGHIJKLMNOÖPQRSTUUÜVWXYZ0123456789.,:-'
        text = pytesseract.image_to_string(thresh, lang='tur+eng', config=custom_config)
        
        # Karakter temizliği
        clean_text = text.lower().replace(';', '.')

        for json_key, pattern in TARGETS.items():
            full_pattern = pattern + r"\D{0,100}?(\d+[\.,]?\d*)"
            match = re.search(full_pattern, clean_text)
            
            if match:
                val_str = match.group(1)
                val_str = val_str.replace(',', '.')
                
                try:
                    val = float(val_str)
                    if json_key in ["Ferritin", "Zinc", "Glukoz"] and val > 500:
                        # Bu değerler tahlillerde genelde 500'den büyük olmaz, muhtemelen virgül kaçmıştır
                        val = val / 100.0
                    elif json_key in ["B12"] and val > 2000:
                        # B12 değeri normal şartlarda binlerce olmaz (300.0 gibi okunmuş olabilir)
                        val = val / 10.0
                    elif json_key in ["D_Vit"] and val > 200:
                        # D vitamini genelde 200'ü geçmez, virgül kaçıp 345 okunduysa 34.5 yaparız
                        val = val / 10.0

                    # 2026 yılı gibi tarih verilerinin elenmesi kuralı korunuyor
                    if 0.1 < val < 4000 and val not in [2023, 2024, 2025, 2026]:
                        if json_key not in results:
                            results[json_key] = val
                except:
                    continue

    if not results:
        return jsonify({"warning": "Değer okunamadı", "data": {}})
        
    return jsonify(results)


# ANA ANALİZ MOTORU 
@app.route("/analyze", methods=["POST"])
def analyze():
    if request.is_json:
        return jsonify(analyze_blood_logic(request.json))
    
    has_image = "image" in request.files
    
    blood_data = {
        "Ferritin": request.form.get("Ferritin"),
        "B12": request.form.get("B12"),
        "D_Vit": request.form.get("D_Vit"),
        "Zinc": request.form.get("Zinc"),
        "Glukoz": request.form.get("Glukoz"),
        "IgE": request.form.get("IgE")
    }
    blood_data = {k: v for k, v in blood_data.items() if v and str(v).strip()}
    has_blood = len(blood_data) > 0

  # SENARYO A: HİBRİT ANALİZ (HEM RESİM HEM MULTİ-KAN KATEGORİZASYONLU)
    if has_image and has_blood:
        if not model: return jsonify({"error": "Model yüklü değil"}), 500
        
        img = Image.open(request.files["image"]).convert("RGB").resize(IMG_SIZE)
        arr = np.expand_dims(np.array(img).astype("float32"), axis=0)
        preds = model(arr)
        preds = list(preds.values())[0] if isinstance(preds, dict) else preds
        preds = tf.nn.softmax(preds).numpy()[0]
        idx = preds.argmax()
        disease_image = classes[idx]
        conf = round(float(preds[idx]) * 100, 2)
        
        blood_result = analyze_blood_logic(blood_data)
        
        combined_herbs = []
        seen_herbs = set()
        
        # 1. CİLT ANALİZİNDEN GELEN BİTKİLER
        if disease_image != "Healthy":
            for h in disease_herbs.get(disease_image, []):
                if h['plant'] not in seen_herbs:
                    herb_copy = h.copy()
                    herb_copy['hedef_hastalik'] = f"📷 Cilt Teşhisi ({disease_image})"
                    combined_herbs.append(herb_copy)
                    seen_herbs.add(h['plant'])
                
        # 2. ÇOKLU KAN DEĞERLERİNDEN GELEN BİTKİLERİ PARAMETREYE GÖRE AYIRMA
        for h in blood_result['herbs']:
            # Bu bitkinin hangi tahlil parametresi (Ferritin, B12 vs.) yüzünden listeye girdiğini buluyoruz
            tahlil_kategorisi = "🩸 Genel Kan Tahlili Önerisi"
            
            for b in blood_result['bulgular']:
                p_adi = b['parametre'] 
                durum = b['durum']     
                ref_hedef = REFERANS_ARALIKLARI.get(p_adi, {})
                
                # Eğer tahlil DÜŞÜKSE ve bitkinin hastalığı 'hedef' ile eşleşiyorsa
                if "Düşük" in durum and ref_hedef.get("hedef") == h["disease"]:
                    tahlil_kategorisi = f"🩸 {p_adi} Eksikliği Kaynaklı"
                    break
                # Eğer tahlil YÜKSEKSE ve bitkinin hastalığı 'hedef_yuksek' ile eşleşiyorsa
                elif "Yüksek" in durum and ref_hedef.get("hedef_yuksek") == h["disease"]:
                    tahlil_kategorisi = f"🩸 {p_adi} Yüksekliği Kaynaklı"
                    break

            # Bitkiyi eşleştiği özel parametre başlığıyla listeye ekliyoruz
            # Kullanıcı her iki değer için de aynı bitkiyi almasın diye bitki adına göre unique (tekil) tutuyoruz
            if h['plant'] not in seen_herbs:
                herb_copy = h.copy()
                herb_copy['hedef_hastalik'] = tahlil_kategorisi
                combined_herbs.append(herb_copy)
                seen_herbs.add(h['plant'])
        
        if disease_image == "Healthy" and not blood_result['bulgular']:
            msg = "✨ Cildiniz ve kan değerleriniz harika görünüyor!"
        else:
            msg = f"📷 Ciltte {disease_image} tespiti ve 🩸 Kan tahlilinde {len(blood_result['bulgular'])} anormallik baz alınarak bütüncül tedavi hazırlanmıştır."
        
        return jsonify({
            "type": "hybrid_result",
            "prediction": msg,
            "hastalik_tahmini": disease_image,
            "ikinci_hastalik_tahmini": f"%{conf} Doğruluk Oranı",
            "bulgular": blood_result['bulgular'],
            "herbs": combined_herbs
        })
    # SENARYO B: SADECE RESİM VAR
    elif has_image:
        if not model: return jsonify({"error": "Model yüklü değil"}), 500
        img = Image.open(request.files["image"]).convert("RGB").resize(IMG_SIZE)
        arr = np.expand_dims(np.array(img).astype("float32"), axis=0)
        preds = model(arr)
        preds = list(preds.values())[0] if isinstance(preds, dict) else preds
        preds = tf.nn.softmax(preds).numpy()[0]
        
        idx = preds.argmax()
        birinci_tahmin = classes[idx]
        
        # CİLT SAĞLIKLIYSA
        if birinci_tahmin == "Healthy":
            return jsonify({
                "type": "image_result", 
                "prediction": "Healthy ✨", 
                "hastalik_tahmini": "Healthy",
                "ikinci_hastalik_tahmini": "Yok",
                "herbs": []
            })
            
        # Eğer cilt sağlıklı değilse, parantezli sistem:
        top_2_idx = preds.argsort()[::-1][:2] 
        ikinci_tahmin = classes[top_2_idx[1]]
        birlestirilmis_tahmin = f"{birinci_tahmin} (İkinci İhtimal: {ikinci_tahmin})"
        
        return jsonify({
            "type": "image_result", 
            "prediction": birlestirilmis_tahmin, 
            "hastalik_tahmini": birinci_tahmin,
            "ikinci_hastalik_tahmini": ikinci_tahmin,
            "herbs": disease_herbs.get(birinci_tahmin, [])
        })

    # SENARYO C: SADECE KAN VAR
    elif has_blood:
        return jsonify(analyze_blood_logic(blood_data))

    return jsonify({"error": "Lütfen analiz için resim veya kan değeri girin."}), 400


@app.route("/analyze/get_random_patient", methods=["GET"])
def get_random_patient():
    return jsonify({
        "Ferritin": 12.5, "B12": 180, "D_Vit": 15, "Zinc": 65, "Glukoz": 95, "IgE": 250, "Teshis": "Demo Hasta"
    })

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 7860)) 
    app.run(host="0.0.0.0", port=port, debug=False)