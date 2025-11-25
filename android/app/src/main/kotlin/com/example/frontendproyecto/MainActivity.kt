package com.example.frontendproyecto

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "app.channel/files"
	private var pendingResult: MethodChannel.Result? = null
	private val REQUEST_CODE_PICK = 9999

	override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			if (call.method == "openDocumentPicker") {
				if (pendingResult != null) {
					result.error("ALREADY_ACTIVE", "Picker already active", null)
					return@setMethodCallHandler
				}
				pendingResult = result
				try {
					val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
					intent.addCategory(Intent.CATEGORY_OPENABLE)
					intent.type = "*/*"
					intent.putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "image/*"))
					startActivityForResult(Intent.createChooser(intent, "Seleccionar archivo"), REQUEST_CODE_PICK)
				} catch (e: Exception) {
					pendingResult = null
					result.error("INTENT_ERROR", e.message, null)
				}
			} else {
				result.notImplemented()
			}
		}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)
		if (requestCode == REQUEST_CODE_PICK) {
			val result = pendingResult ?: return
			if (resultCode == Activity.RESULT_OK && data != null) {
				val uri: Uri? = data.data
				if (uri != null) {
					var name = uri.lastPathSegment ?: "file"
					try {
						val cursor: Cursor? = contentResolver.query(uri, null, null, null, null)
						cursor?.use {
							val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
							if (nameIndex != -1 && it.moveToFirst()) {
								name = it.getString(nameIndex)
							}
						}
					} catch (e: Exception) {
						// ignore
					}
					result.success(name)
				} else {
					result.success(null)
				}
			} else {
				result.success(null)
			}
			pendingResult = null
		}
	}
}
