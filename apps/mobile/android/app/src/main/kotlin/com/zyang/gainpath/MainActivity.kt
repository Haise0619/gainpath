package com.zyang.gainpath

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val soundEffects = SoundEffectsPlugin()

    override fun onResume() {
        super.onResume()
        soundEffects.setForeground(true)
    }

    override fun onPause() {
        soundEffects.setForeground(false)
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(BlazePoseGpuPlugin())
        flutterEngine.plugins.add(WorkoutAudioPlugin())
        flutterEngine.plugins.add(soundEffects)
        flutterEngine.plugins.add(PrivatePdfPlugin())
        flutterEngine.plugins.add(CoachStatementPlugin())
        flutterEngine.plugins.add(WorkoutReportPlugin())
        flutterEngine.plugins.add(AchievementSharePlugin())
        flutterEngine.plugins.add(NetworkOpportunitiesPlugin())
    }
}
