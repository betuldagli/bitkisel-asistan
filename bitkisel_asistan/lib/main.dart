import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

//AYARLAR
const String BASE_URL = "https://betul07-bitkisel-api.hf.space";

const Color primaryGreen = Color(0xFF4A7C59);
const Color accentOrange = Color(0xFFD67D55);
const Color softBackground = Color(0xFFF4F7F5); 
const Color softDarkBackground = Color(0xFF161917);
const Color darkCardColor = Color(0xFF222624);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkTheme') ?? false;
  _themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  runApp(const MyApp());
}

final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier(ThemeMode.light);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Bitkisel Danışman',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
            useMaterial3: true,
            scaffoldBackgroundColor: softBackground,
            appBarTheme: const AppBarTheme(backgroundColor: softBackground, elevation: 0, centerTitle: false),
            cardTheme: CardThemeData(color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen, brightness: Brightness.dark),
            useMaterial3: true,
            scaffoldBackgroundColor: softDarkBackground,
            appBarTheme: const AppBarTheme(backgroundColor: softDarkBackground, elevation: 0, centerTitle: false),
            cardTheme: CardThemeData(color: darkCardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2),
          ),
          home: const IntroScreen(),
        );
      },
    );
  }
}

//BAŞLANGIÇ (INTRO) EKRANI
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.energy_savings_leaf, size: 100, color: primaryGreen),
                const SizedBox(height: 20),
                Text("Bitkisel Danışman", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 10),
                const Text(
                  "Yapay zeka destekli cilt analizi ve kan tahlili yorumlama sistemi.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentOrange.withOpacity(0.5))
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: accentOrange, size: 40),
                      SizedBox(height: 10),
                      Text("Önemli Uyarı", style: TextStyle(fontWeight: FontWeight.bold, color: accentOrange, fontSize: 18)),
                      SizedBox(height: 8),
                      Text(
                        "Bu uygulama yapay zeka tabanlı bir asistan olup, sunduğu bitkisel tavsiyeler kesin tıbbi tedavi yerine geçmez. Lütfen herhangi bir kürü uygulamadan önce doktorunuza veya uzman bir dermatoloğa danışınız.",
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text("Okudum, Onaylıyorum", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//ANA EKRAN
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedImage;
  bool _loading = false;
  Map<String, dynamic>? _result;
  
  final Dio _dio = Dio();
  final ImagePicker _picker = ImagePicker();

  bool get _hasBloodData => 
      _ferritinController.text.isNotEmpty || _b12Controller.text.isNotEmpty || 
      _dVitController.text.isNotEmpty || _zincController.text.isNotEmpty || 
      _glukozController.text.isNotEmpty || _igeController.text.isNotEmpty;

  final Map<String, String> _bloodExplanations = {
    "Ferritin_Düşük": "Demir depoları boşalmış. Saç dökülmesi, solgunluk ve yorgunluğa sebep olabilir.",
    "B12_Düşük": "Ciltte kuruluk, saçlarda incelme ve hücresel yenilenmede yavaşlama yapabilir.",
    "D_Vit_Düşük": "Bağışıklık zayıflar, ciltte egzama veya döküntü eğilimi artar.",
    "Zinc_Düşük": "Hücre yenilenmesi yavaşlar, akne (sivilce) artışı ve tırnak kırılması görülür.",
    "B12_Yüksek": "Aşırı yüksek B12 vitamini, ciltteki akne bakterilerini (P. acnes) besleyerek şiddetli Akne (Sivilce) patlamalarına sebep olabilir.",
    "Ferritin_Yüksek": "Yüksek Ferritin vücutta kronik inflamasyon (iltihap) göstergesidir; Rosacea (Gül Hastalığı) ve cilt kızarıklıklarını tetikleyebilir.",
    "Glukoz_Yüksek": "Yüksek kan şekeri, mikroorganizmaların üremesini kolaylaştırarak Cilt Mantarı (Mantar) gelişimine doğrudan zemin hazırlar.",
    "IgE_Yüksek": "Yüksek IgE seviyesi vücudun aşırı alerjik reaksiyon gösterdiğini kanıtlar; Alerji, Kurdeşen veya Egzama ataklarına sebep olabilir.",

  };
 //DEV BİTKİ KÜTÜPHANESİ (Tüm Cilt ve Kan Bitkileri)
  final Map<String, Map<String, dynamic>> prepInstructions = {
    "Aloe Vera": {
      "title": "Kullanım ve Güvenlik",
      "steps": [
        "• Genel kullanım için oldukça güvenli (safe) bir bitkidir.",
        "• Hassas ciltlerde kullanmadan önce küçük bir bölgede patch-test yapılması önerilir.",
        "• Taze jel, cildi nemlendirirken bariyer onarımını destekler."
      ],
      "img": "img/aloe_vera_stepsT.png"
    },
    "Tea Tree": {
      "title": "Seyreltme ve Tahriş Uyarısı",
      "steps": [
        "• DİKKAT: Cilde doğrudan (saf halde) uygulanmamalıdır; irritasyon riski yüksektir.",
        "• Mutlaka %1-5 oranında bir taşıyıcı yağ ile seyreltilerek kullanılmalıdır.",
        "• Göz ve mukoza bölgeleriyle temasından kaçınılmalıdır."
      ],
      "img": "img/teatree_stepsT.png"
    },
    "Calendula": {
      "title": "Kullanım ve Güvenlik",
      "steps": [
        "• Güvenli (safe) kabul edilen, cilt yenileyici etkisi yüksek bir bitkidir.",
        "• Hücre onarıcı özelliği sayesinde merhem veya yağ formunda günde 3 kez kullanılabilir.",
        "• Bilinen ağır bir yan etkisi yoktur, çocuklarda da dikkatle kullanılabilir."
      ],
      "img": "img/calendula_stepsT.png"
    },
    "Chamomile": {
      "title": "Alerji Uyarısı",
      "steps": [
        "• Genel olarak güvenlidir ancak Asteraceae (Papatyagiller) ailesine alerjisi olanlar dikkat etmelidir.",
        "• Rosacea ve egzama kaynaklı kızarıklıkları gidermede etkilidir."
      ],
      "img": "img/chamomile_stepsT.png"
    },
    "Green Tea": {
      "title": "Antioksidan ve Yağ Dengeleyici",
      "steps": [
        "• KAN DEĞERİ ETKİSİ: İçerdiği EGCG sayesinde kanı temizler ve içsel enflamasyonu (sivilce sebebi) azaltır.",
        "• Cilt için oldukça güvenli ve güçlü bir anti-sebum ajanıdır.",
        "• Demlenmiş çayın soğuduktan sonra tonik olarak kullanılması önerilir."
      ],
      "img": "img/greentea_stepsT.png"
    },
    "Turmeric": {
      "title": "Leke ve Boyama Uyarısı",
      "steps": [
        "• Kurkumin içeriği nedeniyle ciltte geçici sarı lekeler bırakabilir.",
        "• Antiseptik etkisi için lapa olarak 15 dakikadan fazla bekletilmemesi önerilir.",
        "• Hassas ciltlerde hafif yanma hissi yapabilir."
      ],
      "img": "img/turmeric_stepsT.png"
    },
    "Rosemary": {
      "title": "Saç Derisi Uygulaması",
      "steps": [
        "• Saç kökü stimülasyonu için güvenli bir destektir.",
        "• İnfüzyon (çay) formunda durulama suyu olarak kullanılması tavsiye edilir.",
        "• Hamilelik döneminde çok yoğun uçucu yağ kullanımından kaçınılmalıdır."
      ],
      "img": "img/rosemary_stepsT.png"
    },
    "Nettle": {
      "title": "Demir (Ferritin) ve Mineral Desteği",
      "steps": [
        "• KAN DEĞERİ ETKİSİ: Demir (Ferritin) eksikliğinde çay olarak tüketilmesi kan yapımını destekler.",
        "• Saç ve cilt için harici kullanımda güvenli bir mineral kaynağıdır.",
        "• Taze bitkiyle çalışırken temas anındaki yakıcı tüylere karşı eldiven kullanılmalıdır."
      ],
      "img": "img/nettle_stepsT.png"
    },
    "Cade Juniper": {
      "title": "Geleneksel Kullanım Notu",
      "steps": [
        "• Sedef ve egzama için geleneksel ve güvenli bir yöntemdir.",
        "• Keskin kokusu nedeniyle merhem veya şampuan içinde karıştırılarak kullanımı yaygındır.",
        "• Geniş yüzeylere uygulamadan önce küçük bir alanda denenmelidir."
      ],
      "img": "img/cade_juniper_stepsT.png"
    },
    "Burdock": {
      "title": "Kök Dekoksiyonu Güvenliği",
      "steps": [
        "• Kronik cilt sorunlarında kan temizleyici etkisiyle güvenle kullanılabilir.",
        "• Kökleri kaynatırken (dekoksiyon) metal olmayan kaplar tercih edilmelidir.",
        "• Sebum dengesini sağladığı için yağlı cilt ve saç derisine uygundur."
      ],
      "img": "img/burdock_steps1T.png"
    },
    "Sage": {
      "title": "Antiseptik Kullanım",
      "steps": [
        "• Antiseptik ve antifungal özellikleri nedeniyle bölgesel yıkama için güvenlidir.",
        "• Çok yoğun konsantrasyonlarda cildi kurutabilir.",
        "• Hamilelerin adaçayı uçucu yağını topikal olarak kullanırken doktora danışması önerilir."
      ],
      "img": "img/sage_stepsT.png"
    },
    "St. John's Wort": {
      "title": "KRİTİK: Fotosensitivite Uyarısı",
      "steps": [
        "• DİKKAT: Sürüldükten sonra kesinlikle doğrudan güneş ışığına çıkılmamalıdır (leke yapabilir).",
        "• Güçlü yara iyileştiricidir ancak sadece akşamları uygulanması güvenlidir.",
        "• Yağın kırmızı renk alması, etken maddelerin geçtiğini gösterir."
      ],
      "img": "img/st.johnswort_stepsT.jpg"
    },
    "Plantain": {
      "title": "Doğal Yara İyileştirici",
      "steps": [
        "• PFAF verilerine göre doğal yara iyileştirmede oldukça güvenli ve etkilidir.",
        "• Taze yaprak lapası böcek ısırıkları ve küçük kesiklerde acil müdahale için uygundur.",
        "• Bilinen bir yan etkisi yoktur."
      ],
      "img": "img/common_plantain_stepsT.png"
    },
    "Lavender": {
      "title": "Yatıştırıcı ve Antiseptik",
      "steps": [
        "• Uçucu yağlar arasında en güvenli olanlardan biridir ancak yine de seyreltilmesi önerilir.",
        "• Sivilce üzerine bölgesel uygulama için uygundur.",
        "• Yatıştırıcı etkisi nedeniyle gece uygulaması daha verimlidir."
      ],
      "img": "img/lavender_stepsT.png"
    },
    "Chickweed": {
      "title": "Alerji ve Kaşıntı Desteği",
      "steps": [
        "• PFAF 5 yıldız puanlı; alerjik kaşıntılarda en güvenli ve etkili bitkilerden biridir.",
        "• Taze bitki lapası veya merhemi her yaş grubu için uygundur.",
        "• Soğutucu etkisiyle enflamasyonu hızla azaltır."
      ],
      "img": "img/chickweed_stepsT.png"
    },
    "Greater Celandine": {
      "title": "DİKKAT: Tahriş Edici Özsu",
      "steps": [
        "• DİKKAT: Bitkinin sarı özsuyu oldukça yakıcıdır; sadece siğil üzerine sürülmelidir.",
        "• Sağlıklı ciltle temas ettirilmesi durumunda ciddi tahriş yapabilir.",
        "• Gözle temasından kesinlikle kaçınılmalıdır."
      ],
      "img": "img/greater_celandine_stepsT.png"
    },
    "Garlic": {
      "title": "Güçlü Antifungal ve Yakıcı Etki",
      "steps": [
        "• PFAF tıbbi puanı en yüksek bitkilerdendir; güçlü bir antifungaldir.",
        "• Ciltte uzun süre (15-20 dk'dan fazla) bekletilmesi kimyasal yanığa sebep olabilir.",
        "• Uygulama sonrası bölge bol suyla durulanmalıdır."
      ],
      "img": "img/garlic_stepsT.png"
    },
    "Horsetail": {
      "title": "Silis İçeriği ve Güvenlik",
      "steps": [
        "• Yüksek silis içeriği sayesinde saç tellerini güçlendirmede güvenli bir destektir.",
        "• Harici kullanımda (durulama suyu) bilinen bir yan etkisi yoktur.",
        "• Mineral geçişi için demleme süresine dikkat edilmelidir."
      ],
      "img": "img/horsetail_stepsT.png"
    },
    "Licorice": {
      "title": "Doğal Kortizon Etkisi",
      "steps": [
        "• Kızarıklık giderici ve anti-enflamatuar etkisiyle güvenlidir.",
        "• Doğal kortizon benzeri bileşikler içerir, Rosacea için etkilidir.",
        "• Uzun süreli kullanımda cilt rengini dengelemeye yardımcı olur."
      ],
      "img": "img/licorice_stepsT.png"
    },
    "Heartsease": {
      "title": "Çocuklar İçin Uygundur",
      "steps": [
        "• PFAF verilerine göre özellikle çocuklardaki kuru egzamada en güvenli tercihlerdendir.",
        "• Nazik yapısı sayesinde kompres olarak rahatlıkla uygulanabilir.",
        "• Cildi kurutmadan sakinleştirir."
      ],
      "img": "img/heartsease_stepsT.png"
    },
    "Ginkgo": {
      "title": "Antioksidan Koruma",
      "steps": [
        "• Pigment kaybını yavaşlatıcı antioksidan etkisiyle güvenli bir destektir.",
        "• Harici uygulamada cilt toleransı yüksektir.",
        "• Yoğun infüzyon veya hazır ekstrelerin kullanımı önerilir."
      ],
      "img": "img/ginkgo_stepsT.png"
    },
    "Black Walnut": {
      "title": "DİKKAT: Juglon İçeriği",
      "steps": [
        "• DİKKAT: İçerdiği juglon maddesi nedeniyle çok güçlü bir antifungaldir.",
        "• Cildi kahverengiye boyayabilir, bu nedenle bölgesel kullanılmalıdır.",
        "• Açık yaralara uygulanmamalıdır."
      ],
      "img": "img/black_walnut_stepsT.png"
    },
    "Neem": {
      "title": "DİKKAT: Güçlü Antiseptik",
      "steps": [
        "• PFAF uyarısı: Çok güçlü bir antiseptiktir, göz çevresine temas ettirilmemelidir.",
        "• Bazı bünyelerde hassasiyet yapabilir, ilk kullanımda dikkatli olunmalıdır.",
        "• Sivilce ve parazit kaynaklı cilt sorunlarında etkilidir."
      ],
      "img": "img/neem_stepsT.png"
    },
    "Witch Hazel": {
      "title": "Damar Büzücü Güvenliği",
      "steps": [
        "• PFAF verilerine göre damar büzücü (astringent) olarak oldukça güvenlidir.",
        "• Yüzdeki kılcal damar görünümünü ve kızarıklığı hızla yatıştırır.",
        "• Alkol içermeyen distilatlarının (suyu) tercih edilmesi önerilir."
      ],
      "img": "img/witch_hazel_stepsT.png"
    },
    "Thyme": {
      "title": "DİKKAT: Yakıcı Timol",
      "steps": [
        "• DİKKAT: İçerdiği timol nedeniyle cildi yakma potansiyeli çok yüksektir.",
        "• Kesinlikle çok iyi seyreltilmeden (1 damlaya 10 damla su/yağ) kullanılmamalıdır.",
        "• Sadece sorunlu nokta üzerine uygulanmalıdır."
      ],
      "img": "img/thyme_stepsT.png"
    },
    "Gotu Kola": {
      "title": "Hücre Yenileyici",
      "steps": [
        "• PFAF verilerine göre kolajen üretimini destekleyen, güvenli bir bitkidir.",
        "• Yara izleri ve derin egzamalarda hücre yenilenmesini hızlandırır.",
        "• Düzenli kullanımda cilt elastikiyetini artırır."
      ],
      "img": "img/gotu_kola_stepsT.png"
    },
    "Saw Palmetto": {
      "title": "Hormonal Denge Desteği",
      "steps": [
        "• Saç dökülmesine neden olan DHT hormonunu baskılamak için güvenli bir topikal destektir.",
        "• Bilinen ciddi bir topikal yan etkisi yoktur.",
        "• Saç derisine masaj yoluyla uygulanması etkinliğini artırır."
      ],
      "img": "img/saw_palmetto_stepsT.png"
    },
    "Thuja": {
      "title": "DİKKAT: Siğil Uzmanı",
      "steps": [
        "• PFAF 5 yıldız puanlı siğil tedavi edicidir ancak uçucu yağı çok güçlüdür.",
        "• Sadece siğilin tepe noktasına uygulanmalı, sağlıklı deriye değdirilmemelidir.",
        "• Hamilelikte kullanımı önerilmez."
      ],
      "img": "img/thuja_stepsT.png"
    },
    "Peppermint": {
      "title": "Ferahlatıcı ve Yatıştırıcı",
      "steps": [
        "• Mentol etkisiyle kaşıntıyı anında keser, genel olarak güvenlidir.",
        "• Bebeklerde ve çok küçük çocuklarda yüz bölgesine yakın kullanılmamalıdır.",
        "• Soğuk infüzyon formunda kullanımı irritasyonu önler."
      ],
      "img": "img/peppermint_stepsT.png"
    },
    "Oregano": {
      "title": "DİKKAT: Güçlü Antifungal",
      "steps": [
        "• PFAF uyarısı: Karvakrol içeriğiyle en güçlü doğaldır ancak yakıcıdır.",
        "• %2'den fazla yoğunlukta kullanılmamalı ve geniş yüzeylere sürülmemelidir.",
        "• Uygulama sonrası eller iyice yıkanmalıdır."
      ],
      "img": "img/oregano_stepsT.png"
    },
    "Evening Primrose": {
      "title": "Bariyer Onarıcı Güvenliği",
      "steps": [
        "• GLA asidi yönünden zengin, deri bariyerini onarmada oldukça güvenli bir yağdır.",
        "• Egzamalı ve aşırı kuru ciltlerde doğrudan uygulanması önerilir.",
        "• Oral kullanımı da cilt sağlığını destekler."
      ],
      "img": "img/evening_primrose_stepsT.png"
    },
    "Marshmallow": {
      "title": "Yumuşatıcı Müsilaj Etkisi",
      "steps": [
        "• PFAF: Çok yumuşatıcıdır ve tahriş olmuş hassas ciltler için çok güvenlidir.",
        "• Soğuk demleme ile elde edilen jölemsi yapı cildi koruyucu bir tabaka gibi sarar.",
        "• Yanma ve batma hissini hızla alır."
      ],
      "img": "img/marshmallow_stepsT.png"
    },
    "Comfrey": {
      "title": "DİKKAT: Sadece Kapalı Yaralar",
      "steps": [
        "• DİKKAT: İçerdiği allantoin hücreleri çok hızlı böler, bu yüzden AÇIK yaralara sürülmemelidir.",
        "• Sadece kapanmış yara izleri, ezikler veya sağlam deri üzerindeki egzamada kullanılmalıdır.",
        "• Dahili kullanımı (çay olarak) önerilmez."
      ],
      "img": "img/comfrey_stepsT.png"
    },
    "Dandelion": {
      "title": "Cilt Temizleyici",
      "steps": [
        "• Karaciğer desteği ve cilt temizliği için güvenli bir bitkidir.",
        "• Sivilceli ciltlerde fazla yağı dengelemek için tonik olarak kullanılabilir.",
        "• Bilinen bir yan etkisi yoktur."
      ],
      "img": "img/dandelion_stepsT.png"
    },
    "Echinacea": {
      "title": "Bağışıklık Yanıtı Düzenleyici",
      "steps": [
        "• Ciltteki alerjik döküntüleri ve enflamasyonu azaltmada güvenli bir destektir.",
        "• Bağışıklık yanıtını lokal olarak düzenlemeye yardımcı olur.",
        "• Kompres olarak kullanımı oldukça etkilidir."
      ],
      "img": "img/echinacea_stepsT.png"
    },
    "Yarrow": {
      "title": "Büzücü ve Kan Dolaşımı",
      "steps": [
        "• PFAF: Güçlü büzücü (astringent) etkisiyle damar çatlakları için güvenlidir.",
        "• Kan dolaşımını düzenleyerek morluk ve kızarıklıkların iyileşmesini destekler.",
        "• Hamilelikte kullanımı için uzman görüşü alınmalıdır."
      ],
      "img": "img/yarrow_stepsT.png"
    },
    "Black Seed": {
      "title": "IgE (Alerji) ve Geniş Spektrumlu Güvenlik",
      "steps": [
        "• KAN DEĞERİ ETKİSİ: Yüksek IgE (Alerji) durumlarında bağışıklığı modüle etmek için soğuk sıkım yağı dahili olarak tüketilebilir.",
        "• Timokinon içeriğiyle mantar ve sivilceye karşı oldukça güvenli ve etkilidir.",
        "• Soğuk sıkım yağın doğrudan uygulanması deri sağlığını korur."
      ],
      "img": "img/blackseed_stepsT.png"
    },
    "Goldenseal": {
      "title": "DİKKAT: Doğal Antibiyotik",
      "steps": [
        "• Berberin içeriği nedeniyle enfeksiyonlu bölgelerde çok etkilidir.",
        "• Ciltte kısa süreli boyama yapabilir.",
        "• Nadir de olsa bazı ciltlerde yoğun kuruluk yapabileceği için nemlendirici ile desteklenmelidir."
      ],
      "img": "img/goldenseal_stepsT.png"
    },
    "Mullein": {
      "title": "Deri Yumuşatıcı",
      "steps": [
        "• Sertleşmiş deri, nasır ve siğilleri yumuşatmak için oldukça güvenlidir.",
        "• Çiçeklerin yağda bekletilmesiyle elde edilen maserat en etkili formudur.",
        "• Yatıştırıcı etkisi yüksektir."
      ],
      "img": "img/mullein_stepsT.png"
    },
    "Cinnamon": {
      "title": "Glukoz Dengeleyici ve Yakıcı Etki",
      "steps": [
        "• KAN DEĞERİ ETKİSİ: Yüksek Glukoz seviyelerini dengelemek için çaylara veya suya eklenebilir.",
        "• DİKKAT: Tarçın uçucu yağı çok yakıcıdır; kesinlikle doğrudan deriye değmemelidir.",
        "• Yanlışlıkla deriye değerse bölgeyi hemen sabit bir yağla silin."
      ],
      "img": "img/cinnamon_stepsT.png"
    },
    "Lemon Balm": {
      "title": "Hassas Ciltler İçin Uygun",
      "steps": [
        "• Antiviral ve yatıştırıcı etkisiyle tüm cilt tipleri için oldukça güvenlidir.",
        "• Sıcak basması ve kızarıklığı hızla yatıştırır.",
        "• Ferahlatıcı etkisiyle psikolojik rahatlama da sağlar."
      ],
      "img": "img/lemon_balm_stepsT.png"
    },
    "Walnut": {
      "title": "Saç ve Deri Dezenfeksiyonu",
      "steps": [
        "• PFAF: Saç derisini dezenfekte eder ve saç tellerini doğal olarak güçlendirir.",
        "• Açık renkli saçlarda hafif koyulaşma yapabilir.",
        "• Bilinen bir yan etkisi yoktur."
      ],
      "img": "img/black_walnut_steps1T.png"
    },
    "Babchi": {
      "title": "KRİTİK: Pigmentasyon ve Güneş",
      "steps": [
        "• DİKKAT: Psoralen içerir; vitiligo bölgelerinde pigment artırmak için çok dikkatli kullanılmalıdır.",
        "• Uygulama sonrası güneş ışığına maruz kalma süresi profesyonelce ayarlanmalıdır (yanık riski).",
        "• Sadece nokta atışı (bölgesel) uygulama yapılmalıdır."
      ],
      "img": "img/babchi_stepsT.png"
    },
    "Spirulina": {
      "title": "B12 ve Yoğun Vitamin Desteği",
      "steps": [
        "• KAN DEĞERİ ETKİSİ: B12 eksikliği için bitkisel bazlı en güçlü destektir.",
        "• Toz veya tablet formunda günde 1-3 gram arası smoothie veya suya karıştırılarak içilir.",
        "• Deniz yosunu alerjisi olanlar veya tiroid hastaları doktoruna danışmalıdır."
      ],
      "img": "img/spirulina_stepsT.png"
    },
    "Rosehip": {
      "title": "C Vitamini ve Demir (Ferritin) Emilimi",
      "steps": [
        "• KAN DEĞERİ ETKİSİ: Yüksek C vitamini içerir. Demir (Ferritin) eksikliğinde, demirin vücutta emilmesini maksimize eder.",
        "• Günde 1-2 fincan marmelat veya şekersiz çay formunda içilmesi önerilir.",
        "• Mide asidi hassasiyeti olanlar tok karnına tüketmelidir."
      ],
      "img": "img/rosehip_stepsT.png"
    },
    "Pumpkin Seed": {
      "title": "Çinko (Zinc) Kaynağı",
      "steps": [
        "• KAN DEĞERİ ETKİSİ: Çinko (Zinc) eksikliğini gidermede en zengin doğal kaynaklardan biridir.",
        "• Akne ve saç dökülmesini içten tedavi etmek için her gün 1 avuç kavrulmamış (çiğ) kabak çekirdeği tüketilmelidir.",
        "• Cilde harici yağı da sürülebilir ancak asıl etkiyi yenildiğinde gösterir."
      ],
      "img": "img/pumpkin_seed_stepsT.png"
    }
  };
  final TextEditingController _ferritinController = TextEditingController();
  final TextEditingController _b12Controller = TextEditingController();
  final TextEditingController _dVitController = TextEditingController();
  final TextEditingController _zincController = TextEditingController();
  final TextEditingController _glukozController = TextEditingController();
  final TextEditingController _igeController = TextEditingController();

 Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
      
      // Asenkron işlem sonrası sayfa kontrolü
      if (!mounted) return;

      if (pickedFile != null) {
        setState(() { 
          _selectedImage = File(pickedFile.path); 
          _result = null; 
        });
        Navigator.pop(context);
      }
    } catch (e) { 
      _showError("Resim seçilemedi: $e"); 
    }
  }

  Future<void> _startAnalysis() async {
    bool hasImage = _selectedImage != null;
    if (!hasImage && !_hasBloodData) { 
      _showError("Lütfen bir fotoğraf seçin veya kan tahlili ekleyin."); 
      return; 
    }

    setState(() => _loading = true);

    await Future.delayed(const Duration(milliseconds: 200));

    try {
      if (hasImage) {
        String fileName = _selectedImage!.path.split('/').last;
        List<int> imageBytes = await _selectedImage!.readAsBytes();
        
        FormData formData = FormData.fromMap({
          "image": MultipartFile.fromBytes(imageBytes, filename: fileName),
          "Ferritin": _ferritinController.text, 
          "B12": _b12Controller.text, 
          "D_Vit": _dVitController.text, 
          "Zinc": _zincController.text, 
          "Glukoz": _glukozController.text, 
          "IgE": _igeController.text,
        });
        
        print("📡 Ana analiz isteği gönderiliyor...");
        Response response = await _dio.post("$BASE_URL/analyze", data: formData);
        
        if (!mounted) return;
        setState(() => _result = response.data);
      } else {
        Map<String, dynamic> data = {
          "Ferritin": _ferritinController.text, 
          "B12": _b12Controller.text, 
          "D_Vit": _dVitController.text, 
          "Zinc": _zincController.text, 
          "Glukoz": _glukozController.text, 
          "IgE": _igeController.text,
        };
        Response response = await _dio.post("$BASE_URL/analyze", data: data, options: Options(headers: {"Content-Type": "application/json"}));
        
        if (!mounted) return;
        setState(() => _result = response.data);
      }
    } catch (e) { 
      _showErrorDialog("Bağlantı Hatası", "Hata: $e"); 
    } 
    finally { 
      if (mounted) {
        setState(() => _loading = false); 
      }
    }
  }
  Future<void> _scanBloodTest() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if(image == null) return;
    
    if (!mounted) return;
    Navigator.pop(context);
    setState(() => _loading = true);
    
    try {
       FormData formData = FormData.fromMap({
         "image": await MultipartFile.fromFile(image.path, filename: "blood.jpg")
       });
       Response response = await _dio.post("$BASE_URL/analyze/scan_blood_image", data: formData);
       
       if (!mounted) return;
       var data = response.data;
       
       if(data['error'] != null) { 
         _showError(data['error']); 
       } else {
         setState(() {
           _ferritinController.clear(); _b12Controller.clear(); _dVitController.clear(); _zincController.clear(); _glukozController.clear(); _igeController.clear();
           if(data['Ferritin'] != null) _ferritinController.text = data['Ferritin'].toString();
           if(data['B12'] != null) _b12Controller.text = data['B12'].toString();
           if(data['D_Vit'] != null) _dVitController.text = data['D_Vit'].toString();
           if(data['Zinc'] != null) _zincController.text = data['Zinc'].toString();
           if(data['Glukoz'] != null) _glukozController.text = data['Glukoz'].toString();
           if(data['IgE'] != null) _igeController.text = data['IgE'].toString();
         });
         
         // Modal ve snakbar'ı güvenli şekilde tetikliyoruz
         _showBloodModal();
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Tahlil Tarandı!"), backgroundColor: primaryGreen));
       }
    } catch(e) { 
       _showError("OCR HATA DETAYI: $e"); 
       _showBloodModal(); 
    }
    finally { 
       if (mounted) {
         setState(() => _loading = false); 
       }
    }
  }
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("🌿 Bitkisel Danışman", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: primaryGreen),
            onPressed: () async {
              bool newModeIsDark = !isDark;
              _themeNotifier.value = newModeIsDark ? ThemeMode.dark : ThemeMode.light;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isDarkTheme', newModeIsDark);
            },
          )
        ],
      ),
      body: Center( 
        child: ConstrainedBox( 
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildImageCard()), 
                    const SizedBox(width: 15),
                    Expanded(child: _buildBloodCard()), 
                  ],
                ),
                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _startAnalysis,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text("Analiz Et", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),

                if (_loading) const Padding(padding: EdgeInsets.only(top: 30), child: CircularProgressIndicator(color: primaryGreen)),

                if (_result != null && !_loading) ...[
                  const SizedBox(height: 30),
                  _buildResultCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return GestureDetector(
      onTap: _selectedImage == null ? _showUploadMenu : null,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: primaryGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryGreen.withOpacity(0.3), width: 1.5),
        ),
        child: _selectedImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18), 
                    child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() { _selectedImage = null; _result = null; }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  )
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.camera_alt_outlined, size: 40, color: primaryGreen),
                  SizedBox(height: 10),
                  Text("Fotoğraf", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
      ),
    );
  }

  Widget _buildBloodCard() {
    return GestureDetector(
      onTap: _showBloodModal,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: accentOrange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentOrange.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 40, color: accentOrange),
            const SizedBox(height: 10),
            const Text("Tahlil", style: TextStyle(color: accentOrange, fontWeight: FontWeight.bold, fontSize: 16)),
            if (_hasBloodData)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: accentOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle, size: 14, color: accentOrange),
                      SizedBox(width: 4),
                      Text("Veri Girildi", style: TextStyle(color: accentOrange, fontSize: 12, fontWeight: FontWeight.bold))
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

Widget _buildResultCard() {
  bool isBlood = _result!['type'] == 'blood_result';
  bool isHybrid = _result!['type'] == 'hybrid_result';
  
  String predictionText = _result!['prediction'].toString();
  String hastalikTahmini = _result!['hastalik_tahmini']?.toString() ?? "";

  bool isSkinHealthy = hastalikTahmini == "Healthy";

  List<dynamic>? herbs = _result!['herbs'];
  List<dynamic>? findings = _result!['bulgular'];

  // Bitkileri kategorilerine (Cilt Teşhisi, B12 Eksikliği, Ferritin Yüksekliği vs.) göre gruplar
  Map<String, List<dynamic>> groupedHerbs = {};
  if (herbs != null && !isSkinHealthy) { 
    for (var herb in herbs) {
      String category = herb['hedef_hastalik'] ?? "🌿 Genel Öneriler";
      if (!groupedHerbs.containsKey(category)) {
        groupedHerbs[category] = [];
      }
      groupedHerbs[category]!.add(herb);
    }
  }

  String titleText = isHybrid ? '🧬 Hibrit Analiz Raporu' : (isBlood ? '🩸 Tahlil Raporu' : '📷 Cilt Analizi');
  Color titleColor = isHybrid ? const Color(0xFF9D8DF1) : (isBlood ? accentOrange : primaryGreen);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color, 
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSkinHealthy ? Icons.stars : (isHybrid ? Icons.auto_awesome : (isBlood ? Icons.water_drop : Icons.face)), 
                  color: isSkinHealthy ? Colors.amber : titleColor,
                ), 
                const SizedBox(width: 10), 
                Text(
                  isSkinHealthy ? '✨ Tebrikler!' : titleText, 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSkinHealthy ? Colors.amber : titleColor),
                )
              ],
            ),
            const Divider(height: 30),
            
            if (isSkinHealthy) ...[
              const Text(
                "Cildiniz tamamen sağlıklı görünüyor! Cilt bakım rutininize düzenli olarak devam edebilirsiniz. ✨🌿", 
                style: TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w600, color: primaryGreen),
              ),
            ] else ...[
              Text(predictionText, style: const TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w600)),
            ],
            
            if (findings != null && findings.isNotEmpty) ...[
               const SizedBox(height: 20),
               Container(
                 width: double.infinity, 
                 padding: const EdgeInsets.all(15),
                 decoration: BoxDecoration(color: accentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text("📉 Anormal Kan Değerleri:", style: TextStyle(color: accentOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                     const SizedBox(height: 10),
                     ...findings.map<Widget>((item) {
                       String stat = item['durum'].toString().split(' ')[0];
                       String key = "${item['parametre']}_$stat";
                       String desc = _bloodExplanations[key] ?? "";

                       return Padding(
                         padding: const EdgeInsets.only(bottom: 12.0),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text("• ${item['parametre']}: ${item['durum']}", style: TextStyle(color: Colors.redAccent.shade400, fontWeight: FontWeight.bold)),
                             if(desc.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 12, top: 4), child: Text("↳ $desc", style: const TextStyle(fontSize: 13, color: Colors.grey))),
                           ],
                         ),
                       );
                     }).toList(),
                   ],
                 ),
               ),
            ],
          ],
        ),
      ),
      
      if (groupedHerbs.isNotEmpty && !isSkinHealthy) ...[
        const SizedBox(height: 30),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentOrange.withOpacity(0.1), 
            borderRadius: BorderRadius.circular(10), 
            border: Border.all(color: accentOrange.withOpacity(0.3)),
          ),
          child: Row(
            children: const [
              Icon(Icons.health_and_safety, color: accentOrange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Aşağıdaki bitkisel öneriler destekleyicidir. Kullanmadan önce doktorunuza danışınız.", 
                  style: TextStyle(color: accentOrange, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // Kategorilere Göre Kartları Sıralı Çizdirme
        ...groupedHerbs.entries.map((entry) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Padding(
                 padding: const EdgeInsets.only(top: 25, bottom: 15),
                 child: Text(
                   entry.key, // Dinamik başlık basılır (Örn:B12 Eksikliği Kaynaklı veya Ferritin Yüksekliği Kaynaklı)
                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
                 ),
               ),
               LayoutBuilder(
                 builder: (context, constraints) {
                   double width = constraints.maxWidth;
                   int columns = width > 700 ? 3 : (width > 450 ? 2 : 1);
                   double cardWidth = (width - ((columns - 1) * 15)) / columns;

                   return Wrap(
                     spacing: 15, runSpacing: 15,
                     children: entry.value.map((herb) => SizedBox(
                       width: cardWidth,
                       child: _buildHerbCard(herb),
                     )).toList(),
                   );
                 },
               )
             ],
           );
        }).toList(),
      ]
    ],
  );
}
  Widget _buildHerbCard(Map herb) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            herb['image_url'].toString().startsWith("http") ? herb['image_url'] : "$BASE_URL/${herb['image_url']}",
            height: 160, width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (c,e,s) => Container(height: 160, color: Colors.grey.shade200, child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(herb['plant'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text("Dozaj: ${herb['usage_dosage']}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                Text("⚠️ ${herb['notes']}", style: TextStyle(color: accentOrange.withOpacity(0.9), fontSize: 12, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: primaryGreen), padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () => _showPrepModal(herb['plant']), child: const Text("Tarif", style: TextStyle(color: primaryGreen))
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                      onPressed: () => _openVideo(herb['youtube_query']), child: const Text("Video", style: TextStyle(color: Colors.white))
                    )),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showPrepModal(String plantName) {
    String cleanName = plantName.trim();
    String key = prepInstructions.keys.firstWhere((k) => cleanName.contains(k), orElse: () => "Varsayılan");
    var info = prepInstructions[key];
    if(info == null) return;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("$plantName", style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            if(info['img'] != null) 
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), 
                    child: Image.network("$BASE_URL/${info['img']}", fit: BoxFit.contain, errorBuilder: (c,e,s) => const SizedBox.shrink())
                  ),
                ),
              ),
            const SizedBox(height: 15),
            ...(info['steps'] as List).map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s, style: const TextStyle(fontSize: 15, height: 1.4)))).toList(),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kapat", style: TextStyle(color: Colors.grey)))],
    ));
  }

  void _showUploadMenu() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo, color: primaryGreen), title: const Text("Galeriden Seç"), onTap: () => _pickImage(ImageSource.gallery)),
        ListTile(leading: const Icon(Icons.camera_alt, color: primaryGreen), title: const Text("Kamera ile Çek"), onTap: () => _pickImage(ImageSource.camera)),
      ]),
    ));
  }

  void _showBloodModal() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Kan Değerleri", style: TextStyle(color: accentOrange, fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _scanBloodTest, icon: const Icon(Icons.document_scanner), label: const Text("Tahlil Tara (OCR)"),
              style: ElevatedButton.styleFrom(backgroundColor: accentOrange.withOpacity(0.2), foregroundColor: accentOrange, elevation: 0),
            ),
            const SizedBox(height: 15),
            _buildInput("Ferritin", _ferritinController), _buildInput("B12", _b12Controller), _buildInput("D Vit", _dVitController),
            _buildInput("Zinc", _zincController), _buildInput("Glukoz", _glukozController), _buildInput("IgE", _igeController),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
             setState(() {
                _ferritinController.clear(); _b12Controller.clear(); _dVitController.clear(); 
                _zincController.clear(); _glukozController.clear(); _igeController.clear();
                _result = null;
             });
             Navigator.pop(context);
          }, 
          child: const Text("Temizle", style: TextStyle(color: Colors.redAccent))
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: accentOrange, elevation: 0),
          onPressed: () { 
            Navigator.pop(context); 
            setState(() {}); 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veriler hazır. 'Analiz Et' butonuna basın."), backgroundColor: primaryGreen)); 
          }, 
          child: const Text("Kaydet", style: TextStyle(color: Colors.white))
        ),
      ],
    ));
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6), 
      child: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, filled: true, fillColor: Theme.of(context).cardTheme.color, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))
    );
  }

  void _openVideo(String query) async {
    final Uri url = Uri.parse("https://www.youtube.com/results?search_query=$query");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) _showError("Link açılamadı");
  }

  void _showError(String msg) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)); }
  void _showErrorDialog(String t, String c) { showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(t, style: const TextStyle(color: Colors.redAccent)), content: Text(c), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.grey)))])); }
}