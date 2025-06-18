package com.example.eps_moblie

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.app.*
import android.content.Context
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlin.random.Random
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.database.Cursor

class MainActivity : FlutterActivity() {
    private val CHANNEL = "background_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    startBackgroundMonitoring()
                    result.success("Background service started")
                }
                "getErrorsFromDB" -> {
                    val errors = getErrorsFromDatabase()
                    result.success(errors)
                }
                "getAllErrorsForStats" -> {  // 🔥 통계용 모든 에러 조회
                    val errors = getAllErrorsFromDatabase()
                    result.success(errors)
                }
                "getErrorStatistics" -> {
                    val statistics = getErrorStatistics()
                    result.success(statistics)
                }
                "hideError" -> {
                    val errorId = call.argument<Int>("errorId")
                    if (errorId != null) {
                        hideErrorInDatabase(errorId)
                        result.success("Error hidden")
                    } else {
                        result.error("INVALID_ARGUMENT", "Error ID is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun startBackgroundMonitoring() {
        val serviceIntent = Intent(this, BackgroundMonitoringService::class.java)
        startForegroundService(serviceIntent)
    }
    
    private fun getErrorsFromDatabase(): List<Map<String, Any>> {
        val dbHelper = ErrorDatabaseHelper(this)
        val db = dbHelper.readableDatabase
        val errors = mutableListOf<Map<String, Any>>()
        
        val cursor = db.query(
            ErrorDatabaseHelper.TABLE_NAME,
            null,
            "${ErrorDatabaseHelper.COLUMN_IS_HIDDEN} = ?",  // 숨겨지지 않은 것만
            arrayOf("0"),
            null,
            null,
            "${ErrorDatabaseHelper.COLUMN_TIMESTAMP} DESC",
            "20" // 최근 20개만
        )
        
        cursor.use {
            while (it.moveToNext()) {
                val error = mapOf(
                    "id" to it.getInt(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_ID)),
                    "errorCode" to it.getString(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_ERROR_CODE)),
                    "title" to it.getString(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_TITLE)),
                    "timestamp" to it.getLong(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_TIMESTAMP)),
                    "severity" to it.getString(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_SEVERITY)),
                    "site" to it.getString(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_SITE)),
                    "isHidden" to it.getInt(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_IS_HIDDEN))
                )
                errors.add(error)
            }
        }
        
        db.close()
        println("📊 DB에서 ${errors.size}개 에러 조회됨 (숨겨진 것 제외)")
        return errors
    }

    private fun hideErrorInDatabase(errorId: Int) {
        val dbHelper = ErrorDatabaseHelper(this)
        dbHelper.hideError(errorId)
        println("🙈 에러 숨김 처리: ID=$errorId")
    }
    
    private fun getErrorStatistics(): Map<String, Any> {
        val dbHelper = ErrorDatabaseHelper(this)
        val db = dbHelper.readableDatabase
        
        // 🔥 전체 에러 개수
        val totalCursor = db.rawQuery("SELECT COUNT(*) FROM ${ErrorDatabaseHelper.TABLE_NAME}", null)
        val totalCount = if (totalCursor.moveToFirst()) totalCursor.getInt(0) else 0
        totalCursor.close()
        
        // 🔥 숨겨지지 않은 에러 개수
        val visibleCursor = db.rawQuery("SELECT COUNT(*) FROM ${ErrorDatabaseHelper.TABLE_NAME} WHERE ${ErrorDatabaseHelper.COLUMN_IS_HIDDEN} = 0", null)
        val visibleCount = if (visibleCursor.moveToFirst()) visibleCursor.getInt(0) else 0
        visibleCursor.close()
        
        // 🔥 에러 유형별 통계
        val typeStatsCursor = db.rawQuery("""
            SELECT ${ErrorDatabaseHelper.COLUMN_TITLE}, COUNT(*) as count 
            FROM ${ErrorDatabaseHelper.TABLE_NAME} 
            GROUP BY ${ErrorDatabaseHelper.COLUMN_TITLE} 
            ORDER BY count DESC
        """.trimIndent(), null)
        
        val typeStats = mutableListOf<Map<String, Any>>()
        while (typeStatsCursor.moveToNext()) {
            typeStats.add(mapOf(
                "title" to typeStatsCursor.getString(0),
                "count" to typeStatsCursor.getInt(1)
            ))
        }
        typeStatsCursor.close()
        
        // 🔥 최근 24시간 에러 개수
        val twentyFourHoursAgo = System.currentTimeMillis() - (24 * 60 * 60 * 1000)
        val recentCursor = db.rawQuery("""
            SELECT COUNT(*) FROM ${ErrorDatabaseHelper.TABLE_NAME} 
            WHERE ${ErrorDatabaseHelper.COLUMN_TIMESTAMP} > ?
        """.trimIndent(), arrayOf(twentyFourHoursAgo.toString()))
        val recentCount = if (recentCursor.moveToFirst()) recentCursor.getInt(0) else 0
        recentCursor.close()
        
        db.close()
        
        val statistics = mapOf(
            "totalErrors" to totalCount,
            "visibleErrors" to visibleCount,
            "hiddenErrors" to (totalCount - visibleCount),
            "recentErrors24h" to recentCount,
            "errorTypes" to typeStats
        )
        
        println("📊 통계 조회: 총 ${totalCount}개, 24시간 ${recentCount}개, 유형 ${typeStats.size}개")
        return statistics
    }

    // 🔥 통계용: 모든 에러 조회 (제한 없음, 필터 없음)
    private fun getAllErrorsFromDatabase(): List<Map<String, Any>> {
        val dbHelper = ErrorDatabaseHelper(this)
        val db = dbHelper.readableDatabase
        val errors = mutableListOf<Map<String, Any>>()
        
        // 🔥 DB 상태 확인
        val countCursor = db.rawQuery("SELECT COUNT(*) FROM ${ErrorDatabaseHelper.TABLE_NAME}", null)
        val totalCount = if (countCursor.moveToFirst()) countCursor.getInt(0) else 0
        countCursor.close()
        println("🔍 DB 전체 레코드 수: $totalCount")
        
        // 🔥 모든 조건 제거 - 전체 데이터 가져오기
        val cursor = db.query(
            ErrorDatabaseHelper.TABLE_NAME,
            null,
            null,  // 🔥 WHERE 조건 없음 - 모든 데이터
            null,
            null,
            null,
            "${ErrorDatabaseHelper.COLUMN_TIMESTAMP} DESC"
            // 🔥 LIMIT 없음 - 모든 에러 가져오기
        )
        
        cursor.use {
            while (it.moveToNext()) {
                val error = mapOf(
                    "id" to it.getInt(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_ID)),
                    "errorCode" to it.getString(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_ERROR_CODE)),
                    "title" to it.getString(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_TITLE)),
                    "timestamp" to it.getLong(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_TIMESTAMP)),
                    "severity" to it.getString(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_SEVERITY)),
                    "site" to it.getString(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_SITE)),
                    "isHidden" to it.getInt(it.getColumnIndexOrThrow(ErrorDatabaseHelper.COLUMN_IS_HIDDEN))
                )
                errors.add(error)
            }
        }
        
        db.close()
        println("📊 통계용 전체 에러 ${errors.size}개 조회됨 (모든 데이터 포함)")
        return errors
    }
}

// 🔥 에러 데이터베이스 헬퍼
class ErrorDatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
    companion object {
        const val DATABASE_NAME = "server_errors.db"
        const val DATABASE_VERSION = 4  // 🔥 버전 업그레이드 (본사→서울본사 통합)
        const val TABLE_NAME = "errors"
        const val COLUMN_ID = "id"
        const val COLUMN_ERROR_CODE = "error_code"
        const val COLUMN_TITLE = "title"
        const val COLUMN_TIMESTAMP = "timestamp"
        const val COLUMN_SEVERITY = "severity"
        const val COLUMN_IS_HIDDEN = "is_hidden"
        const val COLUMN_SITE = "site"  // 🔥 현장명 컬럼 추가
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTable = """
            CREATE TABLE $TABLE_NAME (
                $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COLUMN_ERROR_CODE TEXT NOT NULL,
                $COLUMN_TITLE TEXT NOT NULL,
                $COLUMN_TIMESTAMP INTEGER NOT NULL,
                $COLUMN_SEVERITY TEXT NOT NULL,
                $COLUMN_IS_HIDDEN INTEGER DEFAULT 0,
                $COLUMN_SITE TEXT NOT NULL DEFAULT '서울본사'
            )
        """.trimIndent()
        db.execSQL(createTable)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            // 기존 테이블에 is_hidden 컬럼 추가
            db.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN $COLUMN_IS_HIDDEN INTEGER DEFAULT 0")
        }
        if (oldVersion < 3) {
            // 🔥 현장명 컬럼 추가
            db.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN $COLUMN_SITE TEXT NOT NULL DEFAULT '서울본사'")
        }
        if (oldVersion < 4) {
            // 🔥 기존 "본사" 데이터를 "서울본사"로 업데이트
            db.execSQL("UPDATE $TABLE_NAME SET $COLUMN_SITE = '서울본사' WHERE $COLUMN_SITE = '본사'")
            println("🔄 데이터베이스 마이그레이션: '본사' → '서울본사' 통합 완료")
        }
    }

    fun insertError(errorCode: String, title: String, timestamp: Long, severity: String, site: String = "서울본사") {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_ERROR_CODE, errorCode)
            put(COLUMN_TITLE, title)
            put(COLUMN_TIMESTAMP, timestamp)
            put(COLUMN_SEVERITY, severity)
            put(COLUMN_IS_HIDDEN, 0)
            put(COLUMN_SITE, site)  // 🔥 현장명 저장
        }
        db.insert(TABLE_NAME, null, values)
        
        // 최대 5000개까지만 유지 (오래된 것 삭제)
        val deleteOld = "DELETE FROM $TABLE_NAME WHERE $COLUMN_ID NOT IN (SELECT $COLUMN_ID FROM $TABLE_NAME ORDER BY $COLUMN_TIMESTAMP DESC LIMIT 5000)"
        db.execSQL(deleteOld)
        
        db.close()
        println("💾 에러 DB 저장: $errorCode - $title [$site]")
    }

    fun hideError(errorId: Int) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_IS_HIDDEN, 1)
        }
        db.update(TABLE_NAME, values, "$COLUMN_ID = ?", arrayOf(errorId.toString()))
        db.close()
        println("🙈 에러 숨김 처리: ID=$errorId")
    }
}

class BackgroundMonitoringService : Service() {
    private val CHANNEL_ID = "server_monitoring_channel"
    private val NOTIFICATION_ID = 12345
    private var handler: Handler? = null
    private var runnable: Runnable? = null
    private lateinit var dbHelper: ErrorDatabaseHelper
    
    private val errorMessages = arrayOf(
        "CPU 사용률 95% 초과",
        "Database 연결 실패",
        "메모리 부족 (임계치 초과)",
        "API 응답 시간 초과",
        "디스크 용량 부족",
        "Network 연결 불안정",
        "SSL 인증서 만료 임박",
        "Redis 캐시 오류",
        "Load Balancer 응답 없음",
        "Background Job 실패"
    )

    // 🔥 현장명 배열 추가
    private val siteNames = arrayOf(
        "서울본사",
        "부산지점",
        "대구지점", 
        "인천지점",
        "광주지점",
        "대전지점",
        "울산지점",
        "제주지점"
    )

    override fun onCreate() {
        super.onCreate()
        dbHelper = ErrorDatabaseHelper(this)
        createNotificationChannel()
        startForegroundService()
        startPeriodicNotifications()
        println("🚀 백그라운드 서버 감시 서비스 시작!")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY // 서비스가 종료되어도 자동으로 재시작
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "서버 24시간 감시",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "서버 모니터링 백그라운드 서비스"
                enableVibration(true)
                enableLights(true)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🔥 서버 24시간 감시 중")
            .setContentText("백그라운드에서 서버를 모니터링하고 있습니다")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setSilent(true)
            .setShowWhen(false)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startPeriodicNotifications() {
        handler = Handler(Looper.getMainLooper())
        runnable = object : Runnable {
            override fun run() {
                generateErrorNotification()
                handler?.postDelayed(this, 1800000) // 30분(1800초)마다 실행
            }
        }
        handler?.post(runnable!!)
    }

    private fun generateErrorNotification() {
        val errorMessage = errorMessages[Random.nextInt(errorMessages.size)]
        val siteName = siteNames[Random.nextInt(siteNames.size)]  // 🔥 랜덤 현장명
        val errorCode = "ERR_${Random.nextInt(999).toString().padStart(3, '0')}"
        val timestamp = System.currentTimeMillis()
        
        // 🔥 데이터베이스에 저장 (현장명 포함)
        dbHelper.insertError(errorCode, errorMessage, timestamp, "Error", siteName)
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🚨 [$siteName] 서버 에러: $errorCode")  // 🔥 현장명 포함
            .setContentText(errorMessage)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 300))
            .build()

        val notificationManager = NotificationManagerCompat.from(this)
        try {
            notificationManager.notify(System.currentTimeMillis().toInt(), notification)
            println("🚨 백그라운드 에러 알림 생성: $errorCode - $errorMessage [$siteName]")
        } catch (e: SecurityException) {
            println("❌ 알림 권한 없음: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler?.removeCallbacks(runnable!!)
        println("⚠️ 백그라운드 서비스 종료")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
