package io.moneef.mobile_app

import android.os.Handler
import android.os.Looper
import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import mobile.Mobile

/**
 * MethodChannel bridge between the Dart layer (`moneef/api`) and the
 * gomobile-bound `mobile.Mobile` Java facade from `moneef.aar`.
 *
 * Every Go function from `mobile/API.md` is wired here. Payloads cross
 * the JNI boundary as `ByteArray`; IDs as 64-bit `Long`.
 */
object MoneefBridge {
    private const val CHANNEL_NAME = "moneef/api"

    // Native (gomobile) calls block on SQLite/HTTP. Running them inside the
    // MethodChannel handler executes them on the platform main thread, freezing
    // the UI — `fetchExchangeRates` does a network round-trip. One worker thread
    // keeps every native call off the UI thread and serialized, matching the
    // single global DB handle the Go side uses; replies hop back to the main
    // thread (Flutter requires Result callbacks there).
    // ponytail: single worker thread; widen to a pool if native throughput ever matters.
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private lateinit var backups: LocalBackups
    private val mutations = setOf("setup", "createTransaction", "updateTransaction", "deleteTransaction", "updateRecurrence", "deleteRecurrence", "createCategory", "updateCategory", "deleteCategory", "upsertExchangeRate", "fetchExchangeRates", "updateProfile", "updateSettings")

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean =
        ::backups.isInitialized && backups.onActivityResult(request, code, data)

    fun register(engine: FlutterEngine, activity: Activity) {
        backups = LocalBackups(activity, MethodChannel(engine.dartExecutor.binaryMessenger, "moneef/backups"), worker, mainHandler)
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                val reply = MainThreadResult(result, mainHandler)
                worker.execute {
                    var succeeded = false
                    val tracked = object : MethodChannel.Result {
                        override fun success(value: Any?) { succeeded = true; reply.success(value) }
                        override fun error(code: String, message: String?, details: Any?) = reply.error(code, message, details)
                        override fun notImplemented() = reply.notImplemented()
                    }
                    dispatch(call, tracked)
                    if (succeeded && (call.method in mutations || call.method == "init")) backups.automaticBackup()
                }
            }
    }

    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                // ── lifecycle ─────────────────────────────────────────
                "init" -> {
                    val dbPath = call.argument<String>("dbPath")!!
                    val profileId = (call.argument<Number>("profileId") ?: 0).toLong()
                    Mobile.init(dbPath, profileId)
                    result.success(null)
                }
                "shutdown" -> {
                    Mobile.shutdown()
                    result.success(null)
                }
                "activeProfileId" -> result.success(Mobile.activeProfileID())
                "setProfileId" -> {
                    val id = (call.argument<Number>("id") ?: 0).toLong()
                    Mobile.setProfileID(id)
                    result.success(null)
                }

                // ── setup ─────────────────────────────────────────────
                "setup" -> result.success(Mobile.setup(payload(call)))

                // ── transactions ──────────────────────────────────────
                "createTransaction" -> result.success(Mobile.createTransaction(payload(call)))
                "listTransactions" -> result.success(Mobile.listTransactions(payload(call)))
                "getTransaction" -> result.success(Mobile.getTransaction(idArg(call)))
                "updateTransaction" -> result.success(
                    Mobile.updateTransaction(idArg(call), payload(call))
                )
                "deleteTransaction" -> {
                    Mobile.deleteTransaction(idArg(call))
                    result.success(null)
                }

                // ── recurrences ───────────────────────────────────────
                "listRecurrences" -> result.success(Mobile.listRecurrences())
                "recurrenceTimeline" -> result.success(Mobile.recurrenceTimeline())
                "updateRecurrence" -> {
                    Mobile.updateRecurrence(idArg(call), payload(call))
                    result.success(null)
                }
                "deleteRecurrence" -> {
                    Mobile.deleteRecurrence(idArg(call))
                    result.success(null)
                }

                // ── currencies ───────────────────────────────────────
                "listCurrencies" -> result.success(Mobile.listCurrencies())

                // ── exchange rates ───────────────────────────────────
                "listExchangeRates" -> result.success(Mobile.listExchangeRates(payload(call)))
                "upsertExchangeRate" -> {
                    Mobile.upsertExchangeRate(payload(call))
                    result.success(null)
                }
                "fetchExchangeRates" -> {
                    Mobile.fetchExchangeRates()
                    result.success(null)
                }

                // ── categories ────────────────────────────────────────
                "listCategories" -> result.success(Mobile.listCategories(payload(call)))
                "createCategory" -> result.success(Mobile.createCategory(payload(call)))
                "updateCategory" -> {
                    Mobile.updateCategory(idArg(call), payload(call))
                    result.success(null)
                }
                "deleteCategory" -> {
                    Mobile.deleteCategory(idArg(call))
                    result.success(null)
                }

                // ── dashboard & analysis ──────────────────────────────
                "dashboard" -> result.success(Mobile.dashboard(payload(call)))
                "analysis" -> result.success(Mobile.analysis(payload(call)))

                // ── patterns ──────────────────────────────────────────
                "patterns" -> result.success(Mobile.patterns())
                "refreshPatterns" -> result.success(Mobile.refreshPatterns(payload(call)))

                // ── profile & settings ────────────────────────────────
                "getProfile" -> result.success(Mobile.getProfile())
                "updateProfile" -> {
                    Mobile.updateProfile(payload(call))
                    result.success(null)
                }
                "getSettings" -> result.success(Mobile.getSettings())
                "updateSettings" -> {
                    Mobile.updateSettings(payload(call))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // Surface Go errors verbatim so Dart can match the sentinels
            // listed in mobile/API.md.
            result.error("MOBILE_ERROR", e.message, e.javaClass.name)
        }
    }

    private fun payload(call: MethodCall): ByteArray =
        call.argument<ByteArray>("payload") ?: ByteArray(0)

    private fun idArg(call: MethodCall): Long =
        (call.argument<Number>("id") ?: 0).toLong()
}

/**
 * Wraps a [MethodChannel.Result] so its callbacks are posted back to the main
 * thread. The native work runs on a worker thread, but Flutter requires the
 * success/error/notImplemented calls to happen on the platform main thread.
 */
private class MainThreadResult(
    private val delegate: MethodChannel.Result,
    private val main: Handler,
) : MethodChannel.Result {
    override fun success(value: Any?) {
        main.post { delegate.success(value) }
    }

    override fun error(code: String, message: String?, details: Any?) {
        main.post { delegate.error(code, message, details) }
    }

    override fun notImplemented() {
        main.post { delegate.notImplemented() }
    }
}
