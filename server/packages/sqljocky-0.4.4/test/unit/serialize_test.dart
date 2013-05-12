library sqljocky;

import 'package:unittest/unittest.dart';
import 'package:logging/logging.dart';
import 'dart:typed_data';
import 'dart:io';

part '../../lib/src/buffer.dart';
part '../../lib/src/mysql_client_error.dart';

final double SMALLEST_POSITIVE_SUBNORMAL_FLOAT = 1.4012984643248170E-45;
final double LARGEST_POSITIVE_SUBNORMAL_FLOAT = 1.1754942106924411E-38;
final double SMALLEST_POSITIVE_NORMAL_FLOAT = 1.1754943508222875E-38;
final double LARGEST_POSITIVE_NORMAL_FLOAT = 3.4028234663852886E+38;

final double LARGEST_NEGATIVE_NORMAL_FLOAT = -1.1754943508222875E-38; // closest to zero
final double SMALLEST_NEGATIVE_NORMAL_FLOAT = -3.4028234663852886E+38; // most negative
final double LARGEST_NEGATIVE_SUBNORMAL_FLOAT = -1.1754942106924411E-38;
final double SMALLEST_NEGATIVE_SUBNORMAL_FLOAT = -1.4012984643248170E-45;

final double SMALLEST_POSITIVE_SUBNORMAL_DOUBLE = 4.9406564584124654E-324;
final double LARGEST_POSITIVE_SUBNORMAL_DOUBLE = 2.2250738585072010E-308;
final double SMALLEST_POSITIVE_NORMAL_DOUBLE = 2.2250738585072014E-308;
final double LARGEST_POSITIVE_NORMAL_DOUBLE = 1.7976931348623157E+308;

final double LARGEST_NEGATIVE_NORMAL_DOUBLE = -2.2250738585072014E-308; // closest to zero
final double SMALLEST_NEGATIVE_NORMAL_DOUBLE = -1.7976931348623157E+308; // most negative
final double LARGEST_NEGATIVE_SUBNORMAL_DOUBLE = -4.9406564584124654E-324;
final double SMALLEST_NEGATIVE_SUBNORMAL_DOUBLE = -2.2250738585072010E-308;

String _BufferToHexString(_Buffer list, [bool reverse=false]) {
  var s = new StringBuffer(); 
  for (int i = 0; i < list.length; i++) {
    var x = list[reverse ? list.length - i - 1 : i].toRadixString(16).toUpperCase();
    if (x.length == 1) {
      s.write("0");
    }
    s.write(x);
  }
  return s.toString();
}

void runSerializationTests() {
  group('serialization:', () {
    test('can write zero float', () {
      var _Buffer = new _Buffer(4);
      var n = 0.0;
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("00000000"));
    });
  
    test('can write zero double', () {
      var _Buffer = new _Buffer(8);
      var n = 0.0;
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("0000000000000000"));
    });
  
    test('can write one or greater float', () {
      var _Buffer = new _Buffer(4);
      var n = 1.0;
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("3F800000"));
      
      n = 100.0;
      _Buffer.reset();
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("42C80000"));
      
      n = 123487.982374;
      _Buffer.reset();
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("47F12FFE"));
  
      n = 10000000000000000000000000000.0;
      _Buffer.reset();
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("6E013F39"));
      
      // TODO: test very large numbers
    });
  
    test('can write one or greater double', () {
      var _Buffer = new _Buffer(8);
      var n = 1.0;
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("3FF0000000000000"));
      
      n = 100.0;
      _Buffer.reset();
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("4059000000000000"));
      
      n = 123487.982374;
      _Buffer.reset();
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("40FE25FFB7CDCCA7"));
  
      n = 10000000000000000000000000000.0;
      _Buffer.reset();
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("45C027E72F1F1281"));
      
      // TODO: test very large numbers
    });
  
    test('can write less than one float', () {
      var _Buffer = new _Buffer(4);
      
      var n = 0.1;
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("3DCCCCCD"));
      
      // TODO: test very small numbers
      n = 3.4028234663852886E+38;
      _Buffer.reset();
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("7F7FFFFF"));
      
      n = 1.1754943508222875E-38;
      _Buffer.reset();
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("00800000"));
      
      n = SMALLEST_POSITIVE_SUBNORMAL_FLOAT / 2;
      _Buffer.reset();
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("00000000"));
    });
  
    test('can write less than one double', () {
      var _Buffer = new _Buffer(8);
      
      var n = 0.1;
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("3FB999999999999A"));
      
      // TODO: test very small numbers
      n = 1.7976931348623157E+308;
      _Buffer.reset();
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("7FEFFFFFFFFFFFFF"));
      
      n = -1.7976931348623157E+308;
      _Buffer.reset();
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("FFEFFFFFFFFFFFFF"));
    });
  
    test('can write non numbers float', () {
      var _Buffer = new _Buffer(4);
      
      var n = 1.0/0.0;
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("7F800000"));
  
      n = -1.0/0.0;
      _Buffer.reset();
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("FF800000"));
  
      n = 0.0/0.0;
      _Buffer.reset();
      _Buffer.writeFloat(n);
      expect(_BufferToHexString(_Buffer, true), equals("FFC00000"));
    });
  
    test('can write non numbers double', () {
      var _Buffer = new _Buffer(8);
      
      var n = 1.0/0.0;
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("7FF0000000000000"));
  
      n = -1.0/0.0;
      _Buffer.reset();
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("FFF0000000000000"));
  
      n = 0.0/0.0;
      _Buffer.reset();
      _Buffer.writeDouble(n);
      expect(_BufferToHexString(_Buffer, true), equals("FFF8000000000000"));
    });
  });
}

void main() {
  runSerializationTests();
}
