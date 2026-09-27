// قراءة معرّف النظام المضمّن — حسب المنصة.
// الويب: لا علامة (النظام من باراميتر الرابط ?sys=).
// التلفون (APK): العلامة ملحقة بذيل ملف التطبيق نفسه.
export 'embedded_marker_stub.dart'
    if (dart.library.io) 'embedded_marker_io.dart';
