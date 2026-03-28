import WidgetKit
import SwiftUI

struct PaymentEntry: TimelineEntry {
    let date: Date
}

struct PaymentProvider: TimelineProvider {
    func placeholder(in context: Context) -> PaymentEntry {
        PaymentEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (PaymentEntry) -> Void) {
        completion(PaymentEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PaymentEntry>) -> Void) {
        completion(Timeline(entries: [PaymentEntry(date: Date())], policy: .never))
    }
}

struct MyFinanceWidgetView: View {
    var body: some View {
        Link(destination: URL(string: "myfinance://payment")!) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.247, green: 0.318, blue: 0.710),
                             Color(red: 0.475, green: 0.525, blue: 0.796)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 10) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Make Payment")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Tap to record")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

@main
struct MyFinanceWidget: Widget {
    let kind: String = "MyFinanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PaymentProvider()) { _ in
            MyFinanceWidgetView()
        }
        .configurationDisplayName("MyFinance")
        .description("Tap to record a payment")
        .supportedFamilies([.systemSmall])
    }
}
