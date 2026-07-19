package com.example.qnn_eco

import android.content.Context
import java.io.File
import org.json.JSONArray
import org.json.JSONObject

/**
 * Private cache of recently observed notifications for the on-device tool.
 * Entries expire after one hour and are removed before every read or write.
 */
class NotificationTemporaryStore(context: Context) {
    private val file = File(context.cacheDir, "notification_triage_recent.json")

    @Synchronized
    fun save(
        packageName: String,
        title: String,
        body: String,
        result: NotificationTriageResult? = null,
        receivedAtMillis: Long = System.currentTimeMillis(),
    ) {
        val records = readValidRecords()
        val record = JSONObject().apply {
            put("packageName", packageName)
            put("title", title.take(MAX_FIELD_LENGTH))
            put("body", body.take(MAX_FIELD_LENGTH))
            put("promotional", result?.isPromotional ?: false)
            put("classification", result?.sentiment?.name?.lowercase())
            put("receivedAt", receivedAtMillis)
        }
        val existingIndex = (0 until records.length()).firstOrNull { index ->
            val existing = records.optJSONObject(index)
            existing != null &&
                existing.optString("packageName") == packageName &&
                existing.optString("title") == title.take(MAX_FIELD_LENGTH) &&
                existing.optString("body") == body.take(MAX_FIELD_LENGTH)
        }
        if (existingIndex != null) records.put(existingIndex, record) else records.put(record)
        while (records.length() > MAX_RECORDS) records.remove(0)
        write(records)
    }

    @Synchronized
    fun summaryForTool(nowMillis: Long = System.currentTimeMillis()): String {
        val records = readValidRecords(nowMillis)
        write(records)
        if (records.length() == 0) {
            return "No notification text is available from the last hour."
        }
        return buildString {
            append("Recent local notifications from the last hour: ${records.length()}. ")
            for (index in 0 until records.length()) {
                val record = records.getJSONObject(index)
                append("[${record.optString("classification", "unclassified")}; ")
                append(record.optString("packageName").substringAfterLast('.'))
                append(": ${record.optString("title")}")
                val body = record.optString("body")
                if (body.isNotBlank()) append(" — $body")
                append("] ")
            }
        }.take(MAX_TOOL_RESULT_LENGTH)
    }

    private fun readValidRecords(nowMillis: Long = System.currentTimeMillis()): JSONArray {
        val records = runCatching {
            if (!file.exists()) JSONArray() else JSONArray(file.readText())
        }.getOrElse { JSONArray() }
        val valid = JSONArray()
        for (index in 0 until records.length()) {
            val record = records.optJSONObject(index) ?: continue
            if (nowMillis - record.optLong("receivedAt", 0) < EXPIRY_MILLIS) valid.put(record)
        }
        return valid
    }

    private fun write(records: JSONArray) {
        if (records.length() == 0) {
            if (file.exists()) file.delete()
            return
        }
        file.writeText(records.toString())
    }

    private companion object {
        const val EXPIRY_MILLIS = 60 * 60 * 1_000L
        const val MAX_RECORDS = 20
        const val MAX_FIELD_LENGTH = 240
        const val MAX_TOOL_RESULT_LENGTH = 3_800
    }
}
