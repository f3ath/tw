import 'package:http_interop/extensions.dart';
import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';

extension InboundDocumentExt on Request {
  Future<Resource> resource() => document().then((it) => it.dataAsResource());

  Future<InboundDocument> document() => body.decodeJson().then((j) => InboundDocument(j));
}
