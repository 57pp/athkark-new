# أذكارك (Athkark) 📱🕌

تطبيق إسلامي شامل للهواتف الذكية يوفر أذكار الصباح والمساء، أوقات الصلاة الدقيقة، قراءة المصحف، والعديد من الميزات الإسلامية الأخرى.

## الميزات الرئيسية ✨

- 🕌 **أوقات الصلاة الدقيقة** - حساب أوقات الصلاة بناءً على الموقع الجغرافي
- 🔔 **إشعارات الأذان** - إشعارات دقيقة لأوقات الصلاة مع صوت الأذان
- 📖 **قراءة المصحف** - قراءة المصحف مع إمكانية التكبير والتصغير
- 🤲 **الأذكار والأدعية** - أذكار الصباح والمساء والنوم والعديد من الأدعية
- 🎯 **العداد الإلكتروني** - عداد الأذكار والتسبيحات
- 🌙 **الصلاة المخصصة** - إمكانية إضافة صلوات مخصصة مع تذكيرات
- 🌙 **وضع مظلم** - دعم الوضع المظلم والفاتح
- 🔊 **صوت الأذان** - ملفات صوتية أصلية للأذان

## متطلبات التشغيل 📋

- Flutter >= 3.5.4
- Dart >= 3.1.0
- Android API 21+ (Android 5.0+)
- iOS 11.0+

## التثبيت والإعداد 🚀

### 1. استنساخ المشروع
```bash
git clone https://github.com/yourusername/athkark.git
cd athkark
```

### 2. تثبيت التبعيات
```bash
flutter pub get
```

### 3. تشغيل التطبيق
```bash
flutter run
```

### 4. بناء التطبيق للنشر
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## التبعيات المهمة 📦

### android_alarm_manager_plus

**Package:** [android_alarm_manager_plus](https://pub.dev/packages/android_alarm_manager_plus)

**Pub Points:** 140/140 🏆

**Popularity:** 95% 📈

**Maintenance:** 100% 🔧

**Versions:** ^5.0.0

A Flutter plugin for accessing the Android AlarmManager service, and running Dart code in the background when alarms fire.

#### Platform Support
- ✅ Android
- ❌ iOS (Not supported - iOS uses different background execution mechanisms)

#### Requirements
- Flutter >=3.12.0
- Dart >=3.1.0 <4.0.0
- Java 17
- Kotlin 2.2.0
- Android Gradle Plugin >=8.12.1
- Gradle wrapper >=8.13

#### Getting Started

**Important:** You would also need a plugin to request SCHEDULE_EXACT_ALARM permission if your app targets Android 14 and newer. Google introduced SCHEDULE_EXACT_ALARM permission in Android 12. In Android 13 it was granted by default. Since Android 14 this permission is denied by default and apps need to ask user to provide it. android_alarm_manager_plus does not provide a way to work with this permission, so be sure to handle such logic yourself. To do so you would need an additional plugin, like permission_handler.

After importing this plugin to your project as usual, add the following to your AndroidManifest.xml within the `<manifest></manifest>` tags:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<!-- For apps with targetSDK 31 (Android 12) and newer -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

Next, within the `<application></application>` tags, add:

```xml
<service
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmService"
    android:permission="android.permission.BIND_JOB_SERVICE"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver"
    android:exported="false"/>
<receiver
    android:name="dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver"
    android:enabled="false"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

Then in Dart code add:

```dart
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// Be sure to annotate your callback function to avoid issues in release mode on Flutter >= 3.3.0
@pragma('vm:entry-point')
static void printHello() {
  final DateTime now = DateTime.now();
  final int isolateId = Isolate.current.hashCode;
  print("[$now] Hello, world! isolate=${isolateId} function='$printHello'");
}

main() async {
  // Be sure to add this line if initialize() call happens before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  await AndroidAlarmManager.initialize();
  runApp(...);
  final int helloAlarmID = 0;
  await AndroidAlarmManager.periodic(const Duration(minutes: 1), helloAlarmID, printHello);
}
```

`printHello` will then run (roughly) every minute, even if the main app ends. However, `printHello` will not run in the same isolate as the main application. Unlike threads, isolates do not share memory and communication between isolates must be done via message passing.

#### Using other plugins in alarm callbacks

If alarm callbacks will need access to other Flutter plugins, including the alarm manager plugin itself, it may be necessary to inform the background service how to initialize plugins depending on which Flutter Android embedding the application is using.

#### Receiving show intents for alarm clocks

If your app is an alarm clock app and sets alarms using the `alarmClock` argument in `oneShot` or `oneShotAt`, you can receive intents when user interacts with system UI that shows the next alarm. An example is the alarm tile in Android quick-setting tiles. This functionality is to allow you to show users the relevant alarm, or allow them to edit it when they tap on such UIs.

This intent has the action `android.intent.action.MAIN` and includes the following extras:

- `id`: The alarm id that you passed when scheduling the alarm.
- `params`: The params argument that you passed when scheduling the alarm, if any.

#### Example

Setting the alarm:

```dart
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

await AndroidAlarmManager.oneShotAt(
    time,
    id,
    callback,
    alarmClock: true,
    params: {
        'param1': 'Hello',
        'param2': 'World'
    }
    ...
)
```

To receive this intent in dart, you can use the receive_intent package:

```dart
import 'package:receive_intent/receive_intent.dart';
import 'dart:convert'; // for jsonDecode

final receivedIntent = await ReceiveIntent.getInitialIntent();
if (receivedIntent.action == "android.intent.action.MAIN"){
    final paramsExtra = receivedIntent.extra?["params"];
    if (paramsExtra != null){
      // The received params is a string, so we need to convert it into a json map
      final params = jsonDecode(params);
      // use params
      // params['param1']
      // params['param2']
    }
    final id = receivedIntent.extra?["id"];
    // navigate user to alarm with given id
}
```

For more information, check out the [receive_intent getting started](https://pub.dev/packages/receive_intent).

#### FAQ

**Does this plugin support to invoke a method after reboot?**

From the Android AlarmManager documentation:

> Registered alarms are retained while the device is asleep (and can optionally wake the device up if they go off during that time), but will be cleared if it is turned off and rebooted.

https://developer.android.com/reference/android/app/AlarmManager

**My alarm is not firing after force stopping the app**

The Android OS will not fire alarms for apps that have been force stopped.

StackOverflow response: https://stackoverflow.com/questions/11241794/alarm-set-in-app-with-alarmmanager-got-removed-when-app-force-stop

**My alarm is not firing on a specific device**

Likely the device is running some battery optimization software that is preventing the alarm from firing. Check out https://dontkillmyapp.com/ to find out about more about optimizations done by different vendors.

## الترخيص 📄

هذا المشروع مرخص تحت رخصة MIT - راجع ملف [LICENSE](LICENSE) للتفاصيل.

## المساهمة 🤝

نرحب بالمساهمات! يرجى قراءة [دليل المساهمة](CONTRIBUTING.md) للبدء.

## الدعم 📞

إذا كان لديك أي أسئلة أو مشاكل، يرجى فتح issue في GitHub أو التواصل معنا عبر البريد الإلكتروني.

## Changelog 📝

### الإصدار 3.0.1
- 🔧 إصلاحات بسيطة وتحسينات في الأداء
- 📦 تحديث الإصدار للإصدارات المستقبلية

### الإصدار 2.0.0
- ✨ إضافة نظام إشعارات شامل للأذان
- 🔔 تحسين دقة أوقات الصلاة
- 📖 إضافة قراءة المصحف التفاعلية
- 🎯 إضافة عداد الأذكار الإلكتروني
- 🌙 دعم الوضع المظلم
- 🔧 تحسينات في الأداء والاستقرار

### الإصدار 1.0.0
- 🕌 إطلاق التطبيق الأولي
- 🤲 أذكار الصباح والمساء
- 🔔 إشعارات أوقات الصلاة
- 📱 واجهة عربية كاملة
