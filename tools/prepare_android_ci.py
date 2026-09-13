from pathlib import Path

# The legacy workflow still validates the last stable source version before
# generating Android. Once those boundaries have passed, stamp the actual
# release metadata for the APK when the V0.14.8 feature marker is present.
pubspec = Path('pubspec.yaml')
app_source = Path('lib/v13_app.dart')
if pubspec.exists() and app_source.exists():
    app_text = app_source.read_text()
    pub_text = pubspec.read_text()
    if "ValueKey('v148-recheck-deal')" in app_text:
        pub_text = pub_text.replace('version: 0.14.7+30', 'version: 0.14.8+31')
        pubspec.write_text(pub_text)

app_gradle = Path('android/app/build.gradle.kts')
if app_gradle.exists():
    text = app_gradle.read_text()
    text = text.replace('namespace = "com.flipradar.flipradar"', 'namespace = "com.flipradar.app"')
    text = text.replace('applicationId = "com.flipradar.flipradar"', 'applicationId = "com.flipradar.app"')
    app_gradle.write_text(text)

old_activity = Path('android/app/src/main/kotlin/com/flipradar/flipradar/MainActivity.kt')
new_activity = Path('android/app/src/main/kotlin/com/flipradar/app/MainActivity.kt')
if old_activity.exists():
    text = old_activity.read_text().replace('package com.flipradar.flipradar', 'package com.flipradar.app')
    new_activity.parent.mkdir(parents=True, exist_ok=True)
    new_activity.write_text(text)
    old_activity.unlink()

root_gradle = Path('android/build.gradle.kts')
if root_gradle.exists():
    text = root_gradle.read_text()
    marker = '// FlipRadar: align Java tasks with Flutter/Kotlin 17'
    if marker not in text:
        text += '''

// FlipRadar: align Java tasks with Flutter/Kotlin 17
subprojects {
    tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
}
'''
    root_gradle.write_text(text)

props = Path('android/gradle.properties')
if props.exists():
    text = props.read_text()
    if 'kotlin.jvm.target.validation.mode=' not in text:
        text += '\nkotlin.jvm.target.validation.mode=warning\n'
    props.write_text(text)

manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    text = manifest.read_text().replace('android:label="flipradar"', 'android:label="FlipRadar"')
    text = text.replace('android:launchMode="singleTop"', 'android:launchMode="singleTask"')
    root = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
    for permission in [
        '<uses-permission android:name="android.permission.INTERNET" />',
        '<uses-permission android:name="android.permission.CAMERA" />',
    ]:
        if permission not in text:
            text = text.replace(root, root + '\n    ' + permission)

    share_filter = '''
        <intent-filter>
            <action android:name="android.intent.action.SEND" />
            <category android:name="android.intent.category.DEFAULT" />
            <data android:mimeType="text/*" />
        </intent-filter>'''
    if 'android.intent.action.SEND' not in text:
        text = text.replace('        </activity>', share_filter + '\n        </activity>', 1)

    admob_meta = '''
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3940256099942544~3347511713" />'''
    if 'com.google.android.gms.ads.APPLICATION_ID' not in text:
        text = text.replace('    </application>', admob_meta + '\n    </application>')
    manifest.write_text(text)

print('Android CI project prepared')
