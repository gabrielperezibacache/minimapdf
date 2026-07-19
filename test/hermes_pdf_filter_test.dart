import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/hermes_pdf_filter.dart';

void main() {
  group('HermesPdfFilter', () {
    test('matriz remapea negro a pergamino y blanco a fondo Obsidian', () {
      final matrix = HermesPdfFilter.obsidianMatrix;

      double apply(int channel, double input) {
        // Matriz 5×4 fila-mayor: a_ii en [row*5 + col], bias en [row*5 + 4].
        final a = matrix[channel * 5 + channel];
        final b = matrix[channel * 5 + 4];
        return a * input + b;
      }

      // Negro (tinta) → #F3ECDD
      expect(apply(0, 0).round(), 0xF3);
      expect(apply(1, 0).round(), 0xEC);
      expect(apply(2, 0).round(), 0xDD);

      // Blanco (papel) → #0F1714
      expect(apply(0, 255).round(), 0x0F);
      expect(apply(1, 255).round(), 0x17);
      expect(apply(2, 255).round(), 0x14);
    });

    test('constantes coinciden con la spec Hermes Obsidian', () {
      expect(HermesPdfFilter.background, const Color(0xFF0F1714));
      expect(HermesPdfFilter.text, const Color(0xFFF3ECDD));
    });
  });
}
