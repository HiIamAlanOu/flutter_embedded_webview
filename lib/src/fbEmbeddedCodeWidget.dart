import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_embedded_webview/src/embeddedCodeType.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FbEmbeddedCodeWidget extends StatefulWidget {
  final String embeddedCode;
  const FbEmbeddedCodeWidget({
    Key? key,
    required this.embeddedCode,
  }) : super(key: key);

  @override
  _FbEmbeddedCodeWidgetState createState() => _FbEmbeddedCodeWidgetState();
}

class _FbEmbeddedCodeWidgetState extends State<FbEmbeddedCodeWidget> {
  late WebViewController _webViewController;
  String _htmlPage = '';
  double _ratio = 16/9;
  RegExpMatch? _regExpMatch;

  @override
  void initState() {
    RegExp regExp = EmbeddedCode.getLaunchUrlRegExpByType(EmbeddedCodeType.facebook)!;
    _regExpMatch = regExp.firstMatch(widget.embeddedCode);

    if(_regExpMatch != null) {
      String fbUrl = _regExpMatch!.group(1)!;
      _htmlPage = 'https://www.facebook.com/plugins/post.php?href='+fbUrl;
      RegExp widthRegExp = RegExp(
        r'width="(.[0-9]*)"',
        caseSensitive: false,
      );
      RegExp heightRegExp = RegExp(
        r'height="(.[0-9]*)"',
        caseSensitive: false,
      );
      double w = double.parse(widthRegExp.firstMatch(widget.embeddedCode)!.group(1)!);
      double h = double.parse(heightRegExp.firstMatch(widget.embeddedCode)!.group(1)!);
      _ratio = w/h;
    }
    super.initState();
  }

  // refer to the link(https://github.com/flutter/flutter/issues/2897)
  // webview will cause the device to crash in some physical android device, 
  // when the webview height is higher than the physical device screen height.
  // --------------------------------------------------
  // width : device screen width - 32(padding) 
  // height : device screen height
  // ratio : webview aspect ratio
  // width / ratio : webview height
  bool _isHigherThanScreenHeight(double width, double height, double ratio) {
    double webviewHeight = width / ratio;
    return webviewHeight >  height;
  }

  double _getIframeHeight(double width, double height, double ratio) {
    if(Platform.isIOS) {
      return width / ratio;
    }

    return _isHigherThanScreenHeight(width, height, ratio) 
      ? height 
      : width / ratio;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width-32;
    var height = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // display iframe
        SizedBox(
          width: width,
          height: _getIframeHeight(width, height, _ratio),
          child: WebView(
            initialUrl: _htmlPage,
            onWebViewCreated: (WebViewController webViewController) {
              _webViewController = webViewController;
            },
            //userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36',
            javascriptMode: JavascriptMode.unrestricted,
            onPageFinished: (e) async{
              double? w = double.tryParse(
                await _webViewController
                    .evaluateJavascript('document.querySelector("._li").getBoundingClientRect().width;'),
              );
              double? h = double.tryParse(
                await _webViewController
                    .evaluateJavascript('document.querySelector("._li").getBoundingClientRect().height;'),
              );

              if(w != null && h != null) {
                double ratio = w/h;
                if(ratio != _ratio) {
                  if(mounted) {
                    setState(() {
                      _ratio = ratio;
                    });
                  }
                }
              }
            },
          ),
        ),
        // display watching more widget when meeting some conditions.
        if(_isHigherThanScreenHeight(width, height, _ratio) && 
            Platform.isAndroid)
          Positioned(
            bottom: 0.0,
            child: _buildWatchingMoreWidget(width),
          ),
        // cover a launching url widget over the iframe 
        InkWell(
          onTap: ()async{
            if(_regExpMatch != null) {
              var url = _regExpMatch!.group(1);
              url = Uri.decodeFull(url!);
              if (await canLaunch(url)) {
                await launch(url);
              } else {
                throw 'Could not launch $url';
              }
            }
          },
          child: Container(
            width: width,
            height: _getIframeHeight(width, height, _ratio),
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }
  
  Widget _buildWatchingMoreWidget(double width) {
    return Container(
      width: width,
      height: width / 16 * 9 / 3,
      color: Colors.black.withOpacity(0.6),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 0.0),
        child: Center(
          child: Text(
            '點擊觀看更多',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}