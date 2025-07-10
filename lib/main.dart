import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/add_place_page.dart';
import 'pages/place_detail_page.dart';
import 'pages/select_profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://pafmkpqdddhmathqpwtp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhZm1rcHFkZGRobWF0aHFwd3RwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg4MjcyNjksImV4cCI6MjA2NDQwMzI2OX0.wKREomhWgCh1xKMTD_kUmXtLb_YxC9VBbyxGOZMpGWw',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Búho Turismo',
      initialRoute: '/select_profile',
      routes: {
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
          final args = settings.arguments as Map<String, dynamic>?;

          if (args == null) {
            // Si no hay argumentos, mostrar pantalla de error simple
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(child: Text('No se recibieron datos del sitio')),
              ),
            );
          }

          return MaterialPageRoute(
            builder: (_) => PlaceDetailPage(place: args),
          );
        }
        return null;
      },
    );
  }
}
