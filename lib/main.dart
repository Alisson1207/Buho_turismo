import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/add_place_page.dart';
import 'pages/place_detail_page.dart';
import 'pages/select_profile_page.dart';
import 'pages/splash_screen.dart';  

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: '',
    anonKey:
        '',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Búho Turismo',
      initialRoute: '/', 
      routes: {
        '/': (_) => const SplashScreen(),  
        '/select_profile': (_) => const SelectProfilePage(),
        '/login': (context) {
          final role = ModalRoute.of(context)?.settings.arguments as String?;
          return LoginPage(role: role ?? 'visitante');
        },
        '/register': (context) {
          final role = ModalRoute.of(context)?.settings.arguments as String?;
          return RegisterPage(role: role ?? 'visitante');
        },
        '/home': (context) {
          final role = ModalRoute.of(context)?.settings.arguments as String?;
          return HomePage(role: role ?? 'visitante');
        },
        '/add_place': (_) => const AddPlacePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/place_detail') {
          final args = settings.arguments;

          if (args == null) {
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(child: Text('No se recibieron datos del sitio')),
              ),
            );
          }

          if (args is Map<String, dynamic> &&
              args.containsKey('place') &&
              args.containsKey('role')) {
            final place = args['place'] as Map<String, dynamic>;
            final role = args['role'] as String;

            return MaterialPageRoute(
              builder: (_) => PlaceDetailPage(place: place, role: role),
            );
          } else {
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(child: Text('Los datos del sitio son inválidos')),
              ),
            );
          }
        }
        return null;
      },
    );
  }
}
