package com.noor.islamic.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class NoorPrayerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.noor_prayer_widget).apply {
                val hijriDate = widgetData.getString("hijri_date", "1448 AH")
                val nextPrayer = widgetData.getString("next_prayer_name", "Fajr")
                val nextPrayerTime = widgetData.getString("next_prayer_time", "05:00")
                val fajr = widgetData.getString("fajr", "04:55")
                val dhuhr = widgetData.getString("dhuhr", "12:15")
                val asr = widgetData.getString("asr", "15:30")
                val maghrib = widgetData.getString("maghrib", "18:05")
                val isha = widgetData.getString("isha", "19:25")

                setTextViewText(R.id.widget_hijri_date, hijriDate)
                setTextViewText(R.id.widget_next_prayer, "$nextPrayer • $nextPrayerTime")
                setTextViewText(R.id.widget_fajr, "Fajr\n$fajr")
                setTextViewText(R.id.widget_dhuhr, "Dhuhr\n$dhuhr")
                setTextViewText(R.id.widget_asr, "Asr\n$asr")
                setTextViewText(R.id.widget_maghrib, "Maghrib\n$maghrib")
                setTextViewText(R.id.widget_isha, "Isha\n$isha")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
