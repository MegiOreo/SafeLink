import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';
//import 'package:safelink/provider/chat_provider.dart';
import 'package:safelink/screens/home_screen.dart';
import 'package:safelink/screens/safelink_chatbot.dart';
import 'package:safelink/services/url_handler_service.dart';
import 'package:safelink/utils/background_handler.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'constants/const.dart';

// void main() {
//   runApp(const MyApp());
// }
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// void main() {
//   runApp(MaterialApp(
//     navigatorKey: navigatorKey,
//     home: HomeScreen(),
//   ));
// }

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.safelink/browser');
  MobileAds.instance.initialize();

  // channel.setMethodCallHandler((call) async {
  //   if (call.method == 'handleQuickCheck') {
  //     final String url = call.arguments;
  //     await UrlHandlerService.processQuickCheckInBackground(url);
  //   }
  // });

  channel.setMethodCallHandler((call) async {
    if (call.method == 'handleQuickCheck') {
      final String url = call.arguments;
      await handleSilentCheck(url);

      // Notify Android that we're done (this will trigger activity.finish())
      await channel.invokeMethod("done");
    }
  });

  Gemini.init(
    apiKey: GEMINI_API_KEY,
  );

  runApp(MyApp());

  // runApp(ChangeNotifierProvider(
  //     create: (context) => ChatProvider(),
  //     child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          //scaffoldBackgroundColor: const Color(0xFF2D2B55),
          //scaffoldBackgroundColor: const Color(0xFFEFEFEF)
          scaffoldBackgroundColor: const Color(0xFF3D8485),
          useMaterial3: true,
        ),
        //home: GeminiChatPage()//HomeScreen()//const MyHomePage(title: 'Flutter Demo Home Page'),
        home: HomeScreen()
    );
  }
}

class MyBannerAdWidget extends StatefulWidget {
  @override
  _MyBannerAdWidgetState createState() => _MyBannerAdWidgetState();
}

class _MyBannerAdWidgetState extends State<MyBannerAdWidget> {
  late BannerAd _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Use test ad unit ID
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Ad failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isAdLoaded
        ? Container(
      alignment: Alignment.center,
      width: _bannerAd.size.width.toDouble(),
      height: _bannerAd.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd),
    )
        : SizedBox.shrink();
  }
}
