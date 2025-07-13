import 'package:flutter/material.dart';

class SelectProfilePage extends StatelessWidget {
  const SelectProfilePage({super.key});

  void _goToLogin(BuildContext context, String role) {
    Navigator.pushReplacementNamed(context, '/login', arguments: role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1361),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo_buho.png', width: 150),
              const SizedBox(height: 40),
              const Text(
                'Selecciona tu perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Botón Visitante
              ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return Colors.white;
                    }
                    return const Color(0xFF1A237E); // Azul oscuro
                  }),
                  foregroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return const Color(0xFF0D1361); // Texto azul oscuro al presionar
                    }
                    return Colors.white; // Texto normal
                  }),
                  minimumSize: MaterialStateProperty.all(const Size(double.infinity, 50)),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                onPressed: () => _goToLogin(context, 'visitante'),
                child: const Text(
                  'Perfil Visitante',
                  style: TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 16),

              // Botón Publicador
              ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return Colors.white;
                    }
                    return const Color(0xFF1A237E); // Mismo color que visitante
                  }),
                  foregroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return const Color(0xFF0D1361);
                    }
                    return Colors.white;
                  }),
                  minimumSize: MaterialStateProperty.all(const Size(double.infinity, 50)),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                onPressed: () => _goToLogin(context, 'publicador'),
                child: const Text(
                  'Perfil Publicador',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
