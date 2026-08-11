const BASE_URL = "https://designated-strong-sam-factory.trycloudflare.com"; 
const themeEmojis = { light: "☀️", dark: "🌙", black: "⚫" };

document.addEventListener("DOMContentLoaded", () => {
  applyTheme(localStorage.getItem("theme") || "light");
});

/* MENÜ VE POPUP İŞLEMLERİ */
function toggleUploadMenu(e) {
  if (e) e.stopPropagation();
  const menu = document.getElementById("uploadMenu");
  menu.style.display = (menu.style.display === "flex") ? "none" : "flex";
  if(menu.style.display === "flex") closeAllMenus(false);
}

function openBloodPopup(e) {
  if (e) e.stopPropagation();
  closeAllMenus();
  document.getElementById("bloodMenu").style.display = "block";
}

function closeBloodPopup(e) {
  if (e) e.stopPropagation();
  document.getElementById("bloodMenu").style.display = "none";
}

function closeAllMenus(closeUpload = true) {
  if(closeUpload) document.getElementById("uploadMenu").style.display = "none";
  document.getElementById("bloodMenu").style.display = "none";
}

function previewImage(e) {
  if (e) e.stopPropagation();
  const file = e.target.files[0];
  if (!file) return;
  const preview = document.getElementById("preview");
  const content = document.getElementById("photoBoxContent");
  preview.src = URL.createObjectURL(file);
  preview.style.display = "block"; 
  if(content) content.style.display = "none";
  preview.onload = function() { URL.revokeObjectURL(preview.src); }
  document.getElementById("uploadMenu").style.display = "none";
}


// 1. Rastgele Hasta Getir
function fillRandomData() {
    const btn = document.getElementById("btnRandom");
    const originalText = btn.innerText;
    btn.innerText = "⏳...";
    btn.disabled = true;

    fetch(`${BASE_URL}/analyze/get_random_patient`)
    .then(res => {
        if (!res.ok) throw new Error("Sunucu Hatası: " + res.status);
        return res.json();
    })
    .then(data => {
        if(data.error) { alert(data.error); return; }
        document.getElementById("inp_ferritin").value = data.Ferritin;
        document.getElementById("inp_b12").value = data.B12;
        document.getElementById("inp_dvit").value = data.D_Vit;
        document.getElementById("inp_zinc").value = data.Zinc;
        document.getElementById("inp_glukoz").value = data.Glukoz;
        document.getElementById("inp_ige").value = data.IgE;
    })
    .catch(err => { 
        console.error(err); 
        alert("HATA DETAYI:\n" + err.message); 
    })
    .finally(() => { btn.innerText = originalText; btn.disabled = false; });
}

// 2. Tahlil Kağıdı Tara (OCR)
function scanBloodTest() {
    const fileInput = document.getElementById("ocrInput");
    const files = fileInput.files;
    const preview = document.getElementById("bloodPreview");
    const label = document.getElementById("ocrLabel");

    if (files.length === 0) return;
    preview.src = URL.createObjectURL(files[0]);
    preview.style.display = "block";
    label.innerHTML = `⏳ Taranıyor...`;
    
    const formData = new FormData();
    for (let i = 0; i < files.length; i++) formData.append("image", files[i]);

    fetch(`${BASE_URL}/analyze/scan_blood_image`, { 
        method: "POST", 
        body: formData
    })
    .then(res => {
        if (!res.ok) throw new Error("Sunucu Hatası: " + res.status);
        return res.json();
    })
    .then(data => {
        if (data.error) { alert(data.error); label.innerHTML = "❌ Hata"; return; }
        
        const fill = (id, val) => {
            if(val) document.getElementById(id).value = val; 
        };
        fill("inp_ferritin", data.Ferritin); fill("inp_b12", data.B12);
        fill("inp_dvit", data.D_Vit); fill("inp_zinc", data.Zinc);
        fill("inp_glukoz", data.Glukoz); fill("inp_ige", data.IgE);

        label.innerHTML = `✅ Tamamlandı!`;
    })
    .catch(err => { 
        console.error(err); 
        alert("HATA DETAYI:\n" + err.message); 
        label.innerHTML = "❌ Hata"; 
    })
    .finally(() => { fileInput.value = ""; });
}

// 3. Bitki/Cilt Analizi
function startAnalysis() {
  const fileInput = document.getElementById("imageInput");
  const cameraInput = document.getElementById("imageInputCamera");
  const file = (fileInput.files.length > 0) ? fileInput.files[0] : (cameraInput.files.length > 0) ? cameraInput.files[0] : null;

  if (!file) { alert("Fotoğraf seçin."); return; }
  showLoader();
  const formData = new FormData();
  formData.append("image", file);

  fetch(`${BASE_URL}/analyze`, { 
      method: "POST", 
      body: formData
  }) 
    .then(res => {
        if (!res.ok) throw new Error("Sunucu Hatası: " + res.status);
        return res.json();
    })
    .then(data => displayResults(data))
    .catch(err => { 
        hideLoader(); 
        console.error(err); 
        alert("HATA DETAYI:\n" + err.message); 
    });
}

// 4. Kan Değerleri Analizi
function startBloodAnalysis() {
    const data = {
        Ferritin: document.getElementById("inp_ferritin").value,
        B12: document.getElementById("inp_b12").value,
        D_Vit: document.getElementById("inp_dvit").value,
        Zinc: document.getElementById("inp_zinc").value,
        Glukoz: document.getElementById("inp_glukoz").value,
        IgE: document.getElementById("inp_ige").value
    };
    
    closeBloodPopup(); 
    showLoader();

    fetch(`${BASE_URL}/analyze`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data)
    })
    .then(res => {
        if (!res.ok) throw new Error("Sunucu Hatası: " + res.status);
        return res.json();
    })
    .then(data => displayResults(data))
    .catch(err => {
        hideLoader();
        console.error(err);
        alert("HATA DETAYI:\n" + err.message);
    });
}

/*SONUÇ GÖSTERİMİ */
function showLoader() {
    document.getElementById("loader").style.display = "block";
    document.getElementById("result").style.display = "none";
}
function hideLoader() {
    document.getElementById("loader").style.display = "none";
}
function displayResults(data) {
    hideLoader();
    const result = document.getElementById("result");
    const resultText = document.getElementById("resultText");
    result.style.display = "block";
    
    result.querySelectorAll(".plant-grid, .section-title, .medical-disclaimer, .healthy-message, .blood-report").forEach(el => el.remove());

    if (data.type === "blood_result") {
        document.getElementById("resultTitle").innerText = "🩸 Tahlil Raporu";
        resultText.innerText = data.prediction;
        if (data.bulgular && data.bulgular.length > 0) {
            const reportDiv = document.createElement("div");
            reportDiv.className = "blood-report";
            reportDiv.style.cssText = "background:rgba(255,243,205,0.6); padding:15px; border-radius:8px; margin-bottom:20px; border:1px solid #ffeeba; text-align:left;";
            let html = "<h4 style='margin-top:0; color:#856404;'>⚠️ Tespitler:</h4><ul style='padding-left:20px; color:#856404;'>";
            data.bulgular.forEach(item => { html += `<li><strong>${item.parametre}:</strong> ${item.durum}</li>`; });
            html += "</ul>";
            reportDiv.innerHTML = html;
            result.appendChild(reportDiv);
            addDisclaimer(result);
        } else {
             const safeDiv = document.createElement("div");
             safeDiv.className = "healthy-message";
             safeDiv.innerHTML = "<strong>✅ Değerleriniz Normal</strong>";
             result.appendChild(safeDiv);
             return; 
        }
    } else {
        document.getElementById("resultTitle").innerText = "📷 Görüntü Analizi";
        resultText.innerText = `Tahmin: ${data.prediction} (%${data.confidence})`;
        if (data.prediction === "Healthy") {
             const healthyDiv = document.createElement("div");
             healthyDiv.innerHTML = "<strong style='color:green'>✨ Cildiniz Sağlıklı Görünüyor!</strong>";
             result.appendChild(healthyDiv);
             return;
        }
        addDisclaimer(result);
    }

    if (data.herbs && data.herbs.length > 0) {
        createSectionTitle(result, "🌿 Önerilen Doğal Çözümler");
        const grid = document.createElement("div");
        grid.className = "plant-grid";
        renderHerbs(data.herbs, grid);
        result.appendChild(grid);
    }
}

function addDisclaimer(container) {
    const d = document.createElement("div");
    d.className = "medical-disclaimer";
    d.innerHTML = `<strong style="color: #e67e22;">⚠️ Uyarı:</strong> Bu analiz tıbbi teşhis değildir. Doktorunuza danışınız.`;
    d.style.cssText = "background:rgba(230,126,34,0.1); border-left:5px solid #e67e22; padding:15px; border-radius:8px; text-align:left; margin:20px 0;";
    container.appendChild(d);
}

function renderHerbs(herbsList, container) {
  herbsList.forEach(herb => {
    const card = document.createElement("div");
    card.className = "plant-card";
    card.innerHTML = `
      <img src="${herb.image_url}" class="herb-thumbnail" alt="${herb.plant}"> 
      <div class="p-header"><strong>🌿 ${herb.plant}</strong></div> 
      <div class="p-body">
        <p><strong>Dozaj:</strong> ${herb.usage_dosage}</p> 
        <p class="p-safety">⚠️ ${herb.notes}</p> 
      </div>
      <div class="p-actions">
        <button onclick="showPrepModal('${herb.plant}')">Nasıl Hazırlanır?</button> 
        <a href="https://www.youtube.com/results?search_query=${herb.youtube_query}" target="_blank">Video İzle</a> 
      </div>
    `;
    container.appendChild(card);
  });
}

function createSectionTitle(container, text) {
  const title = document.createElement("h3");
  title.className = "section-title";
  title.innerText = text;
  container.appendChild(title);
}

function toggleThemeMenu() {
  const m = document.getElementById("themeMenu");
  m.style.display = m.style.display === "block" ? "none" : "block";
}
function setTheme(t) {
  localStorage.setItem("theme", t); applyTheme(t);
  document.getElementById("themeMenu").style.display = "none";
}
function applyTheme(t) {
  document.body.className = "";
  if (t !== "light") document.body.classList.add(t);
  document.getElementById("themeButton").innerText = themeEmojis[t];
}
// Her bitki için hazırlama adımları ve güvenlik uyarılarını içeren veri nesnesi
const prepInstructions = {
  "Aloe Vera": {
    title: "Kullanım ve Güvenlik",
    steps: [
      "• Genel kullanım için oldukça güvenli (safe) bir bitkidir.",
      "• Hassas ciltlerde kullanmadan önce küçük bir bölgede patch-test yapılması önerilir.",
      "• Taze jel, cildi nemlendirirken bariyer onarımını destekler."
    ],
    img: "img/aloe_vera_stepsT.png"
  },
  "Tea Tree": {
    title: "Seyreltme ve Tahriş Uyarısı",
    steps: [
      "• DİKKAT: Cilde doğrudan (saf halde) uygulanmamalıdır; irritasyon riski yüksektir.",
      "• Mutlaka %1-5 oranında bir taşıyıcı yağ ile seyreltilerek kullanılmalıdır.",
      "• Göz ve mukoza bölgeleriyle temasından kaçınılmalıdır."
    ],
    img: "img/teatree_stepsT.png"
  },
  "Calendula / Aynısefa": {
    title: "Kullanım ve Güvenlik",
    steps: [
      "• Güvenli (safe) kabul edilen, cilt yenileyici etkisi yüksek bir bitkidir.",
      "• Hücre onarıcı özelliği sayesinde merhem veya yağ formunda günde 3 kez kullanılabilir.",
      "• Bilinen ağır bir yan etkisi yoktur, çocuklarda da dikkatle kullanılabilir."
    ],
    img: "img/calendula_stepsT.png"
  },
  "Chamomile / Papatya": {
    title: "Alerji Uyarısı",
    steps: [
      "• Genel olarak güvenlidir ancak Asteraceae (Papatyagiller) ailesine alerjisi olanlar dikkat etmelidir.",
      "• Rosacea ve egzama kaynaklı kızarıklıkları gidermede etkilidir."
    ],
    img: "img/chamomile_stepsT.png"
  },
  "Green Tea / Yeşil Çay": {
    title: "Antioksidan Kullanımı",
    steps: [
      "• Cilt için oldukça güvenli ve güçlü bir anti-sebum ajanıdır.",
      "• Demlenmiş çayın soğuduktan sonra tonik olarak kullanılması antioksidan etkisini artırır.",
      "• Ciltteki yağ dengesini korumaya yardımcı olur."
    ],
    img: "img/greentea_stepsT.png"
  },
  "Turmeric / Zerdeçal": {
    title: "Leke ve Boyama Uyarısı",
    steps: [
      "• Kurkumin içeriği nedeniyle ciltte geçici sarı lekeler bırakabilir.",
      "• Antiseptik etkisi için lapa olarak 15 dakikadan fazla bekletilmemesi önerilir.",
      "• Hassas ciltlerde hafif yanma hissi yapabilir."
    ],
    img: "img/turmeric_stepsT.png"
  },
  "Rosemary / Biberiye": {
    title: "Saç Derisi Uygulaması",
    steps: [
      "• Saç kökü stimülasyonu için güvenli bir destektir.",
      "• İnfüzyon (çay) formunda durulama suyu olarak kullanılması tavsiye edilir.",
      "• Hamilelik döneminde çok yoğun uçucu yağ kullanımından kaçınılmalıdır."
    ],
    img: "img/rosemary_stepsT.png"
  },
  "Nettle / Isırgan": {
    title: "Mineral Desteği",
    steps: [
      "• Saç ve cilt için güvenli bir mineral kaynağıdır.",
      "• Taze bitkiyle çalışırken temas anındaki yakıcı tüylere karşı eldiven kullanılmalıdır.",
      "• Hazırlanan suyun taze tüketilmesi ve uygulanması önerilir."
    ],
    img: "img/nettle_stepsT.png"
  },
  "Cade Juniper / Katran Ardıcı": {
    title: "Geleneksel Kullanım Notu",
    steps: [
      "• Sedef ve egzama için geleneksel ve güvenli bir yöntemdir.",
      "• Keskin kokusu nedeniyle merhem veya şampuan içinde karıştırılarak kullanımı yaygındır.",
      "• Geniş yüzeylere uygulamadan önce küçük bir alanda denenmelidir."
    ],
    img: "img/cade_juniper_stepsT.png"
  },
  "Burdock / Dulavratotu": {
    title: "Kök Dekoksiyonu Güvenliği",
    steps: [
      "• Kronik cilt sorunlarında kan temizleyici etkisiyle güvenle kullanılabilir.",
      "• Kökleri kaynatırken (dekoksiyon) metal olmayan kaplar tercih edilmelidir.",
      "• Sebum dengesini sağladığı için yağlı cilt ve saç derisine uygundur."
    ],
    img: "img/burdock_steps1T.png"
  },
  "Adaçayı / Sage": {
    title: "Antiseptik Kullanım",
    steps: [
      "• Antiseptik ve antifungal özellikleri nedeniyle bölgesel yıkama için güvenlidir.",
      "• Çok yoğun konsantrasyonlarda cildi kurutabilir.",
      "• Hamilelerin adaçayı uçucu yağını topikal olarak kullanırken doktora danışması önerilir."
    ],
    img: "img/sage_stepsT.png"
  },
  "St. John's Wort / Sarı Kantaron": {
    title: "KRİTİK: Fotosensitivite Uyarısı",
    steps: [
      "• DİKKAT: Sürüldükten sonra kesinlikle doğrudan güneş ışığına çıkılmamalıdır (leke yapabilir).",
      "• Güçlü yara iyileştiricidir ancak sadece akşamları uygulanması güvenlidir.",
      "• Yağın kırmızı renk alması, etken maddelerin geçtiğini gösterir."
    ],
    img: "img/st.johnswort_stepsT.jpg"
  },
  "Common Plantain / Sinirli Ot": {
    title: "Doğal Yara İyileştirici",
    steps: [
      "• PFAF verilerine göre doğal yara iyileştirmede oldukça güvenli ve etkilidir.",
      "• Taze yaprak lapası böcek ısırıkları ve küçük kesiklerde acil müdahale için uygundur.",
      "• Bilinen bir yan etkisi yoktur."
    ],
    img: "img/common_plantain_stepsT.png"
  },
  "Lavender / Lavanta": {
    title: "Yatıştırıcı ve Antiseptik",
    steps: [
      "• Uçucu yağlar arasında en güvenli olanlardan biridir ancak yine de seyreltilmesi önerilir.",
      "• Sivilce üzerine bölgesel uygulama için uygundur.",
      "• Yatıştırıcı etkisi nedeniyle gece uygulaması daha verimlidir."
    ],
    img: "img/lavender_stepsT.png"
  },
  "Chickweed / Kuşotu": {
    title: "Alerji ve Kaşıntı Desteği",
    steps: [
      "• PFAF 5 yıldız puanlı; alerjik kaşıntılarda en güvenli ve etkili bitkilerden biridir.",
      "• Taze bitki lapası veya merhemi her yaş grubu için uygundur.",
      "• Soğutucu etkisiyle enflamasyonu hızla azaltır."
    ],
    img: "img/chickweed_stepsT.png"
  },
  "Greater Celandine / Kırlangıç Otu": {
    title: "DİKKAT: Tahriş Edici Özsu",
    steps: [
      "• DİKKAT: Bitkinin sarı özsuyu oldukça yakıcıdır; sadece siğil üzerine sürülmelidir.",
      "• Sağlıklı ciltle temas ettirilmesi durumunda ciddi tahriş yapabilir.",
      "• Gözle temasından kesinlikle kaçınılmalıdır."
    ],
    img: "img/greater_celandine_stepsT.png"
  },
  "Garlic / Sarımsak": {
    title: "Güçlü Antifungal ve Yakıcı Etki",
    steps: [
      "• PFAF tıbbi puanı en yüksek bitkilerdendir; güçlü bir antifungaldir.",
      "• Ciltte uzun süre (15-20 dk'dan fazla) bekletilmesi kimyasal yanığa sebep olabilir.",
      "• Uygulama sonrası bölge bol suyla durulanmalıdır."
    ],
    img: "img/garlic_stepsT.png"
  },
  "Horsetail / At Kuyruğu": {
    title: "Silis İçeriği ve Güvenlik",
    steps: [
      "• Yüksek silis içeriği sayesinde saç tellerini güçlendirmede güvenli bir destektir.",
      "• Harici kullanımda (durulama suyu) bilinen bir yan etkisi yoktur.",
      "• Mineral geçişi için demleme süresine dikkat edilmelidir."
    ],
    img: "img/horsetail_stepsT.png"
  },
  "Licorice / Meyan Kökü": {
    title: "Doğal Kortizon Etkisi",
    steps: [
      "• Kızarıklık giderici ve anti-enflamatuar etkisiyle güvenlidir.",
      "• Doğal kortizon benzeri bileşikler içerir, Rosacea için etkilidir.",
      "• Uzun süreli kullanımda cilt rengini dengelemeye yardımcı olur."
    ],
    img: "img/licorice_stepsT.png"
  },
  "Heartsease / Hercai Menekşe": {
    title: "Çocuklar İçin Uygundur",
    steps: [
      "• PFAF verilerine göre özellikle çocuklardaki kuru egzamada en güvenli tercihlerdendir.",
      "• Nazik yapısı sayesinde kompres olarak rahatlıkla uygulanabilir.",
      "• Cildi kurutmadan sakinleştirir."
    ],
    img: "img/heartsease_stepsT.png"
  },
  "Ginkgo / Mabet Ağacı": {
    title: "Antioksidan Koruma",
    steps: [
      "• Pigment kaybını yavaşlatıcı antioksidan etkisiyle güvenli bir destektir.",
      "• Harici uygulamada cilt toleransı yüksektir.",
      "• Yoğun infüzyon veya hazır ekstrelerin kullanımı önerilir."
    ],
    img: "img/ginkgo_stepsT.png"
  },
  "Black Walnut / Kara Ceviz": {
    title: "DİKKAT: Juglon İçeriği",
    steps: [
      "• DİKKAT: İçerdiği juglon maddesi nedeniyle çok güçlü bir antifungaldir.",
      "• Cildi kahverengiye boyayabilir, bu nedenle bölgesel kullanılmalıdır.",
      "• Açık yaralara uygulanmamalıdır."
    ],
    img: "img/black_walnut_stepsT.png"
  },
  "Neem / Yalancı Tesbih Ağacı": {
    title: "DİKKAT: Güçlü Antiseptik",
    steps: [
      "• PFAF uyarısı: Çok güçlü bir antiseptiktir, göz çevresine temas ettirilmemelidir.",
      "• Bazı bünyelerde hassasiyet yapabilir, ilk kullanımda dikkatli olunmalıdır.",
      "• Sivilce ve parazit kaynaklı cilt sorunlarında etkilidir."
    ],
    img: "img/neem_stepsT.png"
  },
  "Witch Hazel / Cadı Fındığı": {
    title: "Damar Büzücü Güvenliği",
    steps: [
      "• PFAF verilerine göre damar büzücü (astringent) olarak oldukça güvenlidir.",
      "• Yüzdeki kılcal damar görünümünü ve kızarıklığı hızla yatıştırır.",
      "• Alkol içermeyen distilatlarının (suyu) tercih edilmesi önerilir."
    ],
    img: "img/witch_hazel_stepsT.png"
  },
  "Thyme / Kekik": {
    title: "DİKKAT: Yakıcı Timol",
    steps: [
      "• DİKKAT: İçerdiği timol nedeniyle cildi yakma potansiyeli çok yüksektir.",
      "• Kesinlikle çok iyi seyreltilmeden (1 damlaya 10 damla su/yağ) kullanılmamalıdır.",
      "• Sadece sorunlu nokta üzerine uygulanmalıdır."
    ],
    img: "img/thyme_stepsT.png"
  },
  "Gotu Kola": {
    title: "Hücre Yenileyici",
    steps: [
      "• PFAF verilerine göre kolajen üretimini destekleyen, güvenli bir bitkidir.",
      "• Yara izleri ve derin egzamalarda hücre yenilenmesini hızlandırır.",
      "• Düzenli kullanımda cilt elastikiyetini artırır."
    ],
    img: "img/gotu_kola_stepsT.png"
  },
  "Saw Palmetto / Cüce Palmiye": {
    title: "Hormonal Denge Desteği",
    steps: [
      "• Saç dökülmesine neden olan DHT hormonunu baskılamak için güvenli bir topikal destektir.",
      "• Bilinen ciddi bir topikal yan etkisi yoktur.",
      "• Saç derisine masaj yoluyla uygulanması etkinliğini artırır."
    ],
    img: "img/saw_palmetto_stepsT.png"
  },
  "Thuja / Mazı": {
    title: "DİKKAT: Siğil Uzmanı",
    steps: [
      "• PFAF 5 yıldız puanlı siğil tedavi edicidir ancak uçucu yağı çok güçlüdür.",
      "• Sadece siğilin tepe noktasına uygulanmalı, sağlıklı deriye değdirilmemelidir.",
      "• Hamilelikte kullanımı önerilmez."
    ],
    img: "img/thuja_stepsT.png"
  },
  "Peppermint / Tıbbi Nane": {
    title: "Ferahlatıcı ve Yatıştırıcı",
    steps: [
      "• Mentol etkisiyle kaşıntıyı anında keser, genel olarak güvenlidir.",
      "• Bebeklerde ve çok küçük çocuklarda yüz bölgesine yakın kullanılmamalıdır.",
      "• Soğuk infüzyon formunda kullanımı irritasyonu önler."
    ],
    img: "img/peppermint_stepsT.png"
  },
  "Oregano / Dağ Kekiği": {
    title: "DİKKAT: Güçlü Antifungal",
    steps: [
      "• PFAF uyarısı: Karvakrol içeriğiyle en güçlü doğaldır ancak yakıcıdır.",
      "• %2'den fazla yoğunlukta kullanılmamalı ve geniş yüzeylere sürülmemelidir.",
      "• Uygulama sonrası eller iyice yıkanmalıdır."
    ],
    img: "img/oregano_stepsT.png"
  },
  "Evening Primrose / Eşek Otu": {
    title: "Bariyer Onarıcı Güvenliği",
    steps: [
      "• GLA asidi yönünden zengin, deri bariyerini onarmada oldukça güvenli bir yağdır.",
      "• Egzamalı ve aşırı kuru ciltlerde doğrudan uygulanması önerilir.",
      "• Oral kullanımı da cilt sağlığını destekler."
    ],
    img: "img/evening_primrose_stepsT.png"
  },
  "Marshmallow / Hatmi": {
    title: "Yumuşatıcı Müsilaj Etkisi",
    steps: [
      "• PFAF: Çok yumuşatıcıdır ve tahriş olmuş hassas ciltler için çok güvenlidir.",
      "• Soğuk demleme ile elde edilen jölemsi yapı cildi koruyucu bir tabaka gibi sarar.",
      "• Yanma ve batma hissini hızla alır."
    ],
    img: "img/marshmallow_stepsT.png"
  },
  "Comfrey / Karakafes Otu": {
    title: "DİKKAT: Sadece Kapalı Yaralar",
    steps: [
      "• DİKKAT: İçerdiği allantoin hücreleri çok hızlı böler, bu yüzden AÇIK yaralara sürülmemelidir.",
      "• Sadece kapanmış yara izleri, ezikler veya sağlam deri üzerindeki egzamada kullanılmalıdır.",
      "• Dahili kullanımı (çay olarak) önerilmez."
    ],
    img: "img/comfrey_stepsT.png"
  },
  "Dandelion / Karahindiba": {
    title: "Cilt Temizleyici",
    steps: [
      "• Karaciğer desteği ve cilt temizliği için güvenli bir bitkidir.",
      "• Sivilceli ciltlerde fazla yağı dengelemek için tonik olarak kullanılabilir.",
      "• Bilinen bir yan etkisi yoktur."
    ],
    img: "img/dandelion_stepsT.png"
  },
  "Echinacea / Ekinezya": {
    title: "Bağışıklık Yanıtı Düzenleyici",
    steps: [
      "• Ciltteki alerjik döküntüleri ve enflamasyonu azaltmada güvenli bir destektir.",
      "• Bağışıklık yanıtını lokal olarak düzenlemeye yardımcı olur.",
      "• Kompres olarak kullanımı oldukça etkilidir."
    ],
    img: "img/echinacea_stepsT.png"
  },
  "Yarrow / Civanperçemi": {
    title: "Büzücü ve Kan Dolaşımı",
    steps: [
      "• PFAF: Güçlü büzücü (astringent) etkisiyle damar çatlakları için güvenlidir.",
      "• Kan dolaşımını düzenleyerek morluk ve kızarıklıkların iyileşmesini destekler.",
      "• Hamilelikte kullanımı için uzman görüşü alınmalıdır."
    ],
    img: "img/yarrow_stepsT.png"
  },
  "Black Seed / Çörek Otu": {
    title: "Geniş Spektrumlu Güvenlik",
    steps: [
      "• Timokinon içeriğiyle mantar ve sivilceye karşı oldukça güvenli ve etkilidir.",
      "• Soğuk sıkım yağın doğrudan uygulanması deri sağlığını korur.",
      "• Günlük kullanıma uygundur."
    ],
    img: "img/blackseed_stepsT.png"
  },
  "Greater Plantain / Sinirli Ot": {
    title: "Acil Müdahale Güvenliği",
    steps: [
      "• PFAF: Histamin etkisini azalttığı için alerjik kaşıntıda 5 yıldız etkilidir.",
      "• Böcek ısırmaları ve ısırgan dalağı gibi durumlarda en güvenli ilk yardımdır.",
      "• Çocuklarda güvenle kullanılabilir."
    ],
    img: "img/greater_plantain_stepsT.png"
  },
  "Goldenseal / Mühür Altın": {
    title: "DİKKAT: Doğal Antibiyotik",
    steps: [
      "• Berberin içeriği nedeniyle enfeksiyonlu bölgelerde çok etkilidir.",
      "• Ciltte kısa süreli boyama yapabilir.",
      "• Nadir de olsa bazı ciltlerde yoğun kuruluk yapabileceği için nemlendirici ile desteklenmelidir."
    ],
    img: "img/goldenseal_stepsT.png"
  },
  "Mullein / Sığır Kuyruğu": {
    title: "Deri Yumuşatıcı",
    steps: [
      "• Sertleşmiş deri, nasır ve siğilleri yumuşatmak için oldukça güvenlidir.",
      "• Çiçeklerin yağda bekletilmesiyle elde edilen maserat en etkili formudur.",
      "• Yatıştırıcı etkisi yüksektir."
    ],
    img: "img/mullein_stepsT.png"
  },
  "Cinnamon / Tarçın": {
    title: "DİKKAT: Çok Yakıcı Etki",
    steps: [
      "• DİKKAT: Tarçın uçucu yağı çok yakıcıdır; kesinlikle doğrudan deriye değmemelidir.",
      "• Sadece tırnak mantarı üzerine, çevresindeki deriyi koruyarak uygulanmalıdır.",
      "• Yanlışlıkla deriye değerse bölgeyi hemen sabit bir yağla silin."
    ],
    img: "img/cinnamon_stepsT.png"
  },
  "Lemon Balm / Oğul Otu": {
    title: "Hassas Ciltler İçin Uygun",
    steps: [
      "• Antiviral ve yatıştırıcı etkisiyle tüm cilt tipleri için oldukça güvenlidir.",
      "• Sıcak basması ve kızarıklığı hızla yatıştırır.",
      "• Ferahlatıcı etkisiyle psikolojik rahatlama da sağlar."
    ],
    img: "img/lemon_balm_stepsT.png"
  },
  "Walnut / Ceviz": {
    title: "Saç ve Deri Dezenfeksiyonu",
    steps: [
      "• PFAF: Saç derisini dezenfekte eder ve saç tellerini doğal olarak güçlendirir.",
      "• Açık renkli saçlarda hafif koyulaşma yapabilir.",
      "• Bilinen bir yan etkisi yoktur."
    ],
    img: "img/black_walnut_steps1T.png"
  },
  "Babchi / Bakuchi": {
    title: "KRİTİK: Pigmentasyon ve Güneş",
    steps: [
      "• DİKKAT: Psoralen içerir; vitiligo bölgelerinde pigment artırmak için çok dikkatli kullanılmalıdır.",
      "• Uygulama sonrası güneş ışığına maruz kalma süresi profesyonelce ayarlanmalıdır (yanık riski).",
      "• Sadece nokta atışı (bölgesel) uygulama yapılmalıdır."
    ],
    img: "img/babchi_stepsT.png"
  }
};

function showPrepModal(plantName) {
  const modal = document.getElementById("prepModal");
  const modalTitle = document.getElementById("modalTitle");
  const modalBody = document.getElementById("modalBody");

  const cleanName = plantName ? plantName.trim() : "";
  let info = prepInstructions[cleanName];

  if (!info) {
      const foundKey = Object.keys(prepInstructions).find(key => cleanName.includes(key));
      info = foundKey ? prepInstructions[foundKey] : prepInstructions["Varsayılan"];
  }

  if (!info) {
      info = {
          title: "Hazırlama Bilgisi",
          steps: ["Bu bitki için özel hazırlama talimatı bulunamadı.", "Genel infüzyon yöntemini uygulayınız."],
          img: "" 
      };
  }

  modalTitle.innerText = `${cleanName} - ${info.title}`;
  let html = `<div class="prep-steps-list">`;
  info.steps.forEach(s => html += `<p class="step-item" style="margin-bottom:8px;">• ${s}</p>`);
  html += `</div>`;
  if(info.img) html += `<img src="${info.img}" class="modal-image" style="width:100%; height:auto; border-radius:12px; margin-top:15px;">`;

  modalBody.innerHTML = html;
  modal.style.display = "block";
}

function closeModal() { document.getElementById("prepModal").style.display = "none"; }
window.onclick = function(event) { if (event.target == document.getElementById("prepModal")) closeModal(); }