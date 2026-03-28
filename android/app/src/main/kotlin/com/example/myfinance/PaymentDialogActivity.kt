package com.example.myfinance

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.view.animation.OvershootInterpolator
import android.widget.*

class PaymentDialogActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        val host = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        setContentView(host)
        showOptionsDialog()
    }

    private fun showOptionsDialog() {
        val dp = resources.displayMetrics.density

        lateinit var dialog: AlertDialog

        fun makeBtn(label: String, bgColor: Int, action: () -> Unit): Button {
            return Button(this).apply {
                text = label
                textSize = 13f
                setTypeface(null, Typeface.BOLD)
                setTextColor(Color.WHITE)
                isAllCaps = false
                background = GradientDrawable().apply {
                    setColor(bgColor)
                    cornerRadius = 10f * dp
                }
                setOnClickListener { dialog.dismiss(); action() }
            }
        }

        fun makeRow(vararg buttons: Button): LinearLayout {
            return LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                for ((i, b) in buttons.withIndex()) {
                    val lp = LinearLayout.LayoutParams(0, (50 * dp).toInt(), 1f)
                    if (i > 0) lp.leftMargin = (8 * dp).toInt()
                    addView(b, lp)
                }
            }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = 20f * dp
                setStroke((2f * dp).toInt(), Color.BLACK)
            }
            setPadding((20 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt())

            // Title
            addView(TextView(this@PaymentDialogActivity).apply {
                text = "Record this payment"
                textSize = 16f
                setTypeface(null, Typeface.BOLD)
                setTextColor(Color.parseColor("#212121"))
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = (14 * dp).toInt() }
            })

            // Row 1: Self | Split
            addView(makeRow(
                makeBtn("\uD83D\uDCB0  Self", Color.parseColor("#43A047")) { showAmountEntryDialog() },
                makeBtn("\uD83E\uDD1D  Split", Color.parseColor("#1E88E5")) { launchApp("split") }
            ), LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (8 * dp).toInt() })

            // Row 2: Loan | Repay
            addView(makeRow(
                makeBtn("\uD83C\uDFE6  Loan", Color.parseColor("#8E24AA")) { launchApp("loan") },
                makeBtn("\uD83D\uDD04  Repay", Color.parseColor("#FB8C00")) { launchApp("repay") }
            ), LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (8 * dp).toInt() })

            // Row 3: No Payment (full width)
            addView(
                makeBtn("\u2715  No Payment", Color.parseColor("#757575")) { finish() },
                LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (46 * dp).toInt())
            )
        }

        dialog = AlertDialog.Builder(this)
            .setView(card)
            .setCancelable(true)
            .create()
        dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        dialog.setOnCancelListener { finish() }
        dialog.show()
    }

    private fun showAmountEntryDialog() {
        val input = EditText(this).apply {
            hint = "Enter amount"
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
            textSize = 20f
            gravity = Gravity.CENTER
            setPadding(20, 24, 20, 24)
        }
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(64, 24, 64, 8)
            addView(input)
        }
        AlertDialog.Builder(this)
            .setTitle("Self Expense")
            .setMessage("How much did you pay?")
            .setView(container)
            .setPositiveButton("Update") { _, _ ->
                val amount = input.text.toString().toDoubleOrNull()
                if (amount != null && amount > 0) {
                    showCategoryDialog(amount)
                } else {
                    Toast.makeText(this, "Enter a valid amount", Toast.LENGTH_SHORT).show()
                    finish()
                }
            }
            .setNegativeButton("Cancel") { _, _ -> finish() }
            .setOnCancelListener { finish() }
            .show()
    }

    private fun showCategoryDialog(amount: Double) {
        val dp = resources.displayMetrics.density
        val categories = listOf(
            Triple("\uD83D\uDE97  Transport", "#1565C0", "Transport"),
            Triple("\uD83C\uDF54  Food",       "#E65100", "Food"),
            Triple("\uD83D\uDC68\u200D\uD83D\uDC69\u200D\uD83D\uDC67  Family",      "#6A1B9A", "Family"),
            Triple("\uD83D\uDC5C  Accessories","#00695C", "Accessories"),
            Triple("\u2022\u2022\u2022  Others",  "#546E7A", "Others")
        )

        lateinit var dialog: AlertDialog

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = 20f * dp
                setStroke((2f * dp).toInt(), Color.BLACK)
            }
            setPadding((20 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt())

            addView(TextView(this@PaymentDialogActivity).apply {
                text = "Select Category"
                textSize = 16f
                setTypeface(null, Typeface.BOLD)
                setTextColor(Color.parseColor("#212121"))
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = (14 * dp).toInt() }
            })

            for ((label, colorHex, category) in categories) {
                val btn = Button(this@PaymentDialogActivity).apply {
                    text = label
                    textSize = 13f
                    setTypeface(null, Typeface.BOLD)
                    setTextColor(Color.WHITE)
                    isAllCaps = false
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor(colorHex))
                        cornerRadius = 10f * dp
                    }
                    setOnClickListener {
                        dialog.dismiss()
                        savePendingExpense(amount, category)
                        showSuccessScreen()
                    }
                }
                addView(btn, LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    (48 * dp).toInt()
                ).apply { bottomMargin = (8 * dp).toInt() })
            }
        }

        dialog = AlertDialog.Builder(this)
            .setView(card)
            .setCancelable(true)
            .create()
        dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        dialog.setOnCancelListener { finish() }
        dialog.show()
    }

    private fun savePendingExpense(amount: Double, category: String = "") {
        val prefs = getSharedPreferences("myfinance_prefs", Context.MODE_PRIVATE)
        val existing = prefs.getString("pending_personal_expenses", "") ?: ""
        val entry = if (category.isNotEmpty()) "$amount|$category" else "$amount"
        val newVal = if (existing.isEmpty()) entry else "$existing,$entry"
        prefs.edit().putString("pending_personal_expenses", newVal).apply()
    }

    private fun showSuccessScreen() {
        val dp = resources.displayMetrics.density

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.WHITE)
            setPadding((32 * dp).toInt(), (80 * dp).toInt(), (32 * dp).toInt(), (80 * dp).toInt())
        }

        val circleSize = (140 * dp).toInt()
        val circle = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(circleSize, circleSize).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = (20 * dp).toInt()
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#E8F5E9"))
            }
        }

        val tickView = TextView(this).apply {
            text = "\u2713"
            textSize = 72f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.parseColor("#4CAF50"))
            gravity = Gravity.CENTER
            scaleX = 0f
            scaleY = 0f
        }
        circle.addView(tickView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        ))

        val messageView = TextView(this).apply {
            text = "Transaction added to\nPersonal Expense"
            textSize = 16f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.parseColor("#212121"))
            gravity = Gravity.CENTER
            setPadding(0, (8 * dp).toInt(), 0, 0)
        }

        layout.addView(circle)
        layout.addView(messageView)

        val successDialog = AlertDialog.Builder(this)
            .setView(layout)
            .setCancelable(false)
            .create()
        successDialog.window?.setBackgroundDrawable(ColorDrawable(Color.WHITE))
        successDialog.show()

        val scaleX = ObjectAnimator.ofFloat(tickView, "scaleX", 0f, 1.3f, 1f)
        val scaleY = ObjectAnimator.ofFloat(tickView, "scaleY", 0f, 1.3f, 1f)
        AnimatorSet().apply {
            playTogether(scaleX, scaleY)
            duration = 500
            interpolator = OvershootInterpolator(2f)
            start()
        }

        Handler(Looper.getMainLooper()).postDelayed({
            successDialog.dismiss()
            finish()
        }, 2200)
    }

    private fun launchApp(action: String) {
        val prefs = getSharedPreferences("myfinance_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("pending_action", action).apply()
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(intent)
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        @Suppress("DEPRECATION")
        super.onBackPressed()
        finish()
    }
}
