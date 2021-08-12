

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sides/sides.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

class MockHttp extends Mock implements http.MultipartRequest
{
  @override
  final Map<String, String> headers = {};
  @override
  final fields = <String, String>{};
}



void main() async
{
  await WidgetsFlutterBinding.ensureInitialized();
  test('Given Server upload is OK, err:null', () async
  {
    int sol =0;
    final mockHttp = MockHttp();
    when(mockHttp.send()).thenAnswer((_) async => http.StreamedResponse(Stream.value([0]), 200),);


    //var dir = await getExternalStorageDirectory();
    await backup();

    var dir = await getExternalStorageDirectory();
    if(dir != null)
    {
      sol = await dir.list().length;
    }
    expect( sol, 0);


  });
  test('Given Server upload is not OK', () async
  {

    int sol =0;
    int prev=0;
    final mockHttp = MockHttp();
    when(mockHttp.send()).thenAnswer((_) async => http.StreamedResponse(Stream.value([0]),404 ),);
    var dir = await getExternalStorageDirectory();
    if(dir != null)
    {
      prev = await dir.list().length;
    }
    await backup();
    if(dir != null)
    {
      sol = await dir.list().length;
    }
    expect( sol, prev);



  });
}