import 'package:flutter_test/flutter_test.dart';

import 'package:accountingsystem/systems/system_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('روابط الفروع الرمزية v1..v100', () {
    test('v1 يُحوَّل إلى branch1 ويُعامل كفرع ديناميكي', () {
      SystemConfig.instance.init(Uri.parse('https://x.app/?sys=v1'));
      expect(SystemConfig.instance.systemId, 'branch1');
      expect(SystemConfig.instance.pendingDynamicId, 'branch1');
      expect(SystemConfig.instance.isAdmin, false);
    });

    test('v4 يُحوَّل إلى branch4', () {
      SystemConfig.instance.init(Uri.parse('https://x.app/?sys=v4'));
      expect(SystemConfig.instance.systemId, 'branch4');
      expect(SystemConfig.instance.pendingDynamicId, 'branch4');
    });

    test('الصيغة الكاملة branch2 ما زالت تعمل (توافق قديم)', () {
      SystemConfig.instance.init(Uri.parse('https://x.app/?sys=branch2'));
      expect(SystemConfig.instance.systemId, 'branch2');
      expect(SystemConfig.instance.pendingDynamicId, 'branch2');
    });

    test('بدون معامل يفتح الأدمن', () {
      SystemConfig.instance.init(Uri.parse('https://x.app/'));
      expect(SystemConfig.instance.isAdmin, true);
    });

    test('cloudUrlFor يولّد الروابط القصيرة للفروع', () {
      expect(
        SystemConfig.cloudUrlFor('branch1'),
        'https://accountingsystem-fc3f0.web.app/?sys=v1',
      );
      expect(
        SystemConfig.cloudUrlFor('branch12'),
        'https://accountingsystem-fc3f0.web.app/?sys=v12',
      );
      expect(
        SystemConfig.cloudUrlFor('admin'),
        'https://accountingsystem-fc3f0.web.app/?sys=admin',
      );
    });

    test('v1 كبير الحرف V1 يقبل أيضاً', () {
      SystemConfig.instance.init(Uri.parse('https://x.app/?sys=V1'));
      expect(SystemConfig.instance.systemId, 'branch1');
    });
  });
}
