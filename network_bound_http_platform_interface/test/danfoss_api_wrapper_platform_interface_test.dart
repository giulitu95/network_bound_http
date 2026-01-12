import 'package:danfoss_api_wrapper_platform_interface/channel_danfoss_api_wrapper.dart';
import 'package:danfoss_api_wrapper_platform_interface/danfoss_api_wrapper_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class DanfossApiWrappePlatformMock extends Mock
    with MockPlatformInterfaceMixin
    implements DanfossApiWrapperPlatform {}

class ImplementsUrlLauncherPlatform extends Mock
    implements DanfossApiWrapperPlatform {}

class ExtendsUrlLauncherPlatform extends DanfossApiWrapperPlatform {}

void main() {
  group('DanfossApiWrapperPlatformInterface -', () {
    test('$ChannelDanfossApiWrapper() is the default instance', () {
      expect(
        DanfossApiWrapperPlatform.instance,
        isInstanceOf<ChannelDanfossApiWrapper>(),
      );
    });

    test('cannot be implemented with `implements`', () {
      expect(() {
        DanfossApiWrapperPlatform.instance = ImplementsUrlLauncherPlatform();
      }, throwsA(isInstanceOf<AssertionError>()));
    });

    test('can be mocked with `implements`', () {
      final DanfossApiWrappePlatformMock mock = DanfossApiWrappePlatformMock();
      DanfossApiWrapperPlatform.instance = mock;
    });

    test('can be extended', () {
      DanfossApiWrapperPlatform.instance = ExtendsUrlLauncherPlatform();
    });

    test('initialize', () {
      final instance = ExtendsUrlLauncherPlatform();
      expect(
        () => instance.initialize(),
        throwsA(isInstanceOf<UnimplementedError>()),
      );
    });

    test('callService', () {
      final instance = ExtendsUrlLauncherPlatform();
      expect(
        () => instance.callService(''),
        throwsA(isInstanceOf<UnimplementedError>()),
      );
    });

    test('callbackStream', () {
      final instance = ExtendsUrlLauncherPlatform();
      expect(
        () => instance.callbackStream,
        throwsA(isInstanceOf<UnimplementedError>()),
      );
    });
  });
}
