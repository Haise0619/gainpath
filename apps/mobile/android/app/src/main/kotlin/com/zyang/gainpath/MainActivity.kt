package com.zyang.gainpath

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(BlazePoseGpuPlugin())
        flutterEngine.plugins.add(WorkoutAudioPlugin())
        flutterEngine.plugins.add(PrivatePdfPlugin())
        flutterEngine.plugins.add(CoachStatementPlugin())
    }
}
