package io.moneef.mobile_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel
import mobile.Mobile
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.zip.ZipInputStream

/** Local SAF documents only. All disk/core operations share the API's worker. */
class LocalBackups(
    private val activity: Activity,
    private val channel: MethodChannel,
    private val worker: ExecutorService,
    private val main: Handler,
) {
    private val context = activity.applicationContext
    private val resolver = context.contentResolver
    private val prefs = context.getSharedPreferences("moneef_local_backups", Context.MODE_PRIVATE)
    private var picker: MethodChannel.Result? = null
    private var busy = false
    private val limit = 256L * 1024 * 1024

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "chooseFolder") {
                chooseFolder(result)
            } else worker.execute {
                try {
                    val value: Any? = when (call.method) {
                        "status" -> status()
                        "dismiss" -> { prefs.edit().putBoolean("dismissed", true).commit(); status() }
                        "configure" -> {
                            val folder = localFolder(call.argument<String>("folder")!!)
                            // Test listing before replacing a previously working destination.
                            children(folder)
                            prefs.edit().putString("folder", folder.toString())
                                .remove("lastBackup").remove("error").commit()
                            backupNow()
                            status()
                        }
                        "backupNow" -> { backupNow(); status() }
                        "list" -> listBackups(localFolder(call.argument<String>("folder")!!))
                        "restore" -> restore(
                            localFolder(call.argument<String>("folder")!!),
                            call.argument<String>("uri")!!,
                        )
                        else -> { main.post { result.notImplemented() }; return@execute }
                    }
                    main.post { result.success(value) }
                } catch (e: Exception) {
                    main.post { result.error("BACKUP_ERROR", e.message ?: "Could not access the backup folder.", null) }
                }
            }
        }
    }

    private fun chooseFolder(result: MethodChannel.Result) {
        if (picker != null) { result.error("BACKUP_BUSY", "A folder picker is already open.", null); return }
        picker = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            putExtra(Intent.EXTRA_LOCAL_ONLY, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        try { activity.startActivityForResult(intent, REQUEST_FOLDER) }
        catch (e: Exception) { picker = null; result.error("BACKUP_ERROR", e.message, null) }
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != REQUEST_FOLDER) return false
        val result = picker ?: return true
        picker = null
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null) { result.success(null); return true }
        try {
            localFolder(uri.toString())
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            resolver.takePersistableUriPermission(uri, flags)
            result.success(mapOf("uri" to uri.toString(), "name" to folderName(uri)))
        } catch (e: Exception) { result.error("BACKUP_ERROR", e.message, null) }
        return true
    }

    private fun localFolder(value: String): Uri {
        val uri = Uri.parse(value)
        require(uri.scheme == "content" && uri.authority == "com.android.externalstorage.documents" && DocumentsContract.isTreeUri(uri)) {
            "Choose a folder in this device's storage or an SD card, such as Documents/Moneef Backups."
        }
        return uri
    }

    private fun folderName(uri: Uri): String = DocumentsContract.getTreeDocumentId(uri)
        .replace("primary:", "Internal storage / ").replace(":", " / ")

    private fun status(): Map<String, Any?> {
        val folder = prefs.getString("folder", null)
        return mapOf(
            "supported" to true, "enabled" to (folder != null), "folder" to folder,
            "folderName" to folder?.let { folderName(Uri.parse(it)) },
            "lastBackup" to prefs.getString("lastBackup", null),
            "error" to prefs.getString("error", null), "busy" to busy,
            "dismissed" to prefs.getBoolean("dismissed", false),
        )
    }

    private fun publish() { val value = status(); main.post { channel.invokeMethod("statusChanged", value) } }

    /** Called after successful data changes and on boot, never changes CRUD results. */
    fun automaticBackup() {
        if (prefs.getString("folder", null) == null || Mobile.activeProfileID() <= 0) return
        try { backupNow() } catch (_: Exception) { /* status keeps the error for retry */ }
    }

    private fun backupNow() {
        val folder = localFolder(prefs.getString("folder", null) ?: error("Choose a backup folder first."))
        busy = true
        publish()
        val temp = File(context.cacheDir, "backup-${UUID.randomUUID()}.zip")
        var document: Uri? = null
        try {
            val metadata = JSONObject(String(Mobile.createBackup(temp.absolutePath), Charsets.UTF_8))
            val series = prefs.getString("series", null) ?: UUID.randomUUID().toString().also {
                prefs.edit().putString("series", it).commit()
            }
            val stamp = metadata.getString("created_at").replace(Regex("[^0-9T]"), "")
            val name = "moneef-$series-$stamp-${UUID.randomUUID()}.moneefbackup"
            val parent = DocumentsContract.buildDocumentUriUsingTree(folder, DocumentsContract.getTreeDocumentId(folder))
            document = DocumentsContract.createDocument(resolver, parent, "application/octet-stream", "$name.partial")
                ?: error("Could not create a backup in this folder.")
            resolver.openFileDescriptor(document, "w")?.let { descriptor ->
                android.os.ParcelFileDescriptor.AutoCloseOutputStream(descriptor).use { out ->
                    temp.inputStream().use { it.copyTo(out) }
                    out.flush()
                    out.fd.sync()
                }
            } ?: error("Could not write the backup file.")
            // Incomplete writes never appear in the restore list.
            document = DocumentsContract.renameDocument(resolver, document, name)
                ?: error("Could not finish the backup file.")
            prefs.edit().putString("lastBackup", metadata.getString("created_at")).remove("error").commit()
            // Only prune this installation's files. Existing archives from a
            // previous install or another profile remain untouched.
            runCatching {
                children(folder).filter { it.second.startsWith("moneef-$series-") && it.second.endsWith(".moneefbackup") }
                    .sortedByDescending { it.second }.drop(7).forEach { DocumentsContract.deleteDocument(resolver, it.first) }
            }
        } catch (e: Exception) {
            document?.let { runCatching { DocumentsContract.deleteDocument(resolver, it) } }
            prefs.edit().putString("error", "Your data is saved in Moneef, but the backup could not be updated. Check the folder and try again.").commit()
            throw e
        } finally {
            temp.delete()
            busy = false
            publish()
        }
    }

    private fun children(folder: Uri): List<Pair<Uri, String>> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(folder, DocumentsContract.getTreeDocumentId(folder))
        val result = mutableListOf<Pair<Uri, String>>()
        val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME)
        resolver.query(uri, columns, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                result.add(DocumentsContract.buildDocumentUriUsingTree(folder, cursor.getString(0)) to cursor.getString(1))
            }
        } ?: error("This folder is unavailable. Choose it again to grant access.")
        return result
    }

    private fun listBackups(folder: Uri): Map<String, Any?> {
        var unreadable = 0
        val backups = children(folder).filter { it.second.startsWith("moneef-") && it.second.endsWith(".moneefbackup") }.mapNotNull { (uri, name) ->
            try {
                val metadata = resolver.openInputStream(uri)?.use { input ->
                    ZipInputStream(input).use { zip ->
                        require(zip.nextEntry?.name == "manifest.json")
                        val bytes = ByteArray(16385)
                        var size = 0
                        while (size < bytes.size) {
                            val n = zip.read(bytes, size, bytes.size - size)
                            if (n < 0) break
                            size += n
                        }
                        require(size <= 16384)
                        JSONObject(String(bytes, 0, size, Charsets.UTF_8))
                    }
                } ?: error("Unreadable backup")
                require(metadata.getString("format") == "moneef-local-backup" && metadata.getInt("version") == 1)
                mapOf("uri" to uri.toString(), "name" to name, "createdAt" to metadata.getString("created_at"), "transactionCount" to metadata.getLong("transaction_count"))
            } catch (_: Exception) { unreadable++; null }
        }.sortedByDescending { it["createdAt"] as String }
        return mapOf("backups" to backups, "unreadable" to unreadable)
    }

    private fun restore(folder: Uri, value: String): Map<String, Any?> {
        // Accept only a document listed in the selected tree, not an arbitrary URI.
        val source = children(folder).firstOrNull { it.first.toString() == value && it.second.endsWith(".moneefbackup") }
            ?: error("This backup is no longer in the selected folder.")
        val temp = File(context.cacheDir, "restore-${UUID.randomUUID()}.zip")
        busy = true
        publish()
        try {
            resolver.openInputStream(source.first)?.use { input ->
                temp.outputStream().use { out ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        total += n
                        require(total <= limit) { "Backup exceeds 256 MB." }
                        out.write(buffer, 0, n)
                    }
                }
            } ?: error("Could not read this backup.")
            val info = JSONObject(String(Mobile.restoreBackup(temp.absolutePath), Charsets.UTF_8))
            prefs.edit().putString("folder", folder.toString()).putString("lastBackup", info.getString("created_at"))
                .remove("error").putBoolean("dismissed", true).commit()
            return mapOf("profileId" to info.getLong("profile_id"))
        } finally {
            temp.delete()
            busy = false
            publish()
        }
    }

    companion object { const val REQUEST_FOLDER = 7301 }
}
