package com.example.pathwise

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

class HomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_widget_layout).apply {
                val data = widgetData.getString("goal_data", null)
                if (data != null) {
                    val goal = JSONObject(data)
                    val title = goal.getString("title")
                    val stepsArray = goal.getJSONArray("steps")
                    var stepsText = ""
                    for (i in 0 until stepsArray.length()) {
                        val step = stepsArray.getJSONObject(i)
                        val stepTitle = step.getString("title")
                        val isCompleted = step.getBoolean("isCompleted")
                        stepsText += if (isCompleted) "✓ $stepTitle\n" else "○ $stepTitle\n"
                    }

                    setTextViewText(R.id.widget_title, title)
                    setTextViewText(R.id.widget_steps, stepsText.trim())
                } else {
                    setTextViewText(R.id.widget_title, "Your Goal")
                    setTextViewText(R.id.widget_steps, "Open the app and long-press a goal to display it here.")
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}