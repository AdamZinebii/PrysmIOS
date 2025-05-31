import SwiftUI
import Charts
import Foundation

// Use only the shared models from TrackerDataModels.swift
// Remove any local AssetPriceData or AssetPriceHistoryPoint definitions

struct AssetPriceView: View {
    let symbol: String
    @State private var priceData: AssetPriceData?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: { fetchPriceData() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if let data = priceData {
                // Current Price Section
                VStack(spacing: 8) {
                    Text("$\(data.currentPrice ?? 0, specifier: "%.2f")")
                        .font(.system(size: 32, weight: .bold))
                    if let priceChange = data.priceChange {
                        HStack {
                            Image(systemName: priceChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text("\(abs(priceChange), specifier: "%.2f")%")
                        }
                        .foregroundColor(priceChange >= 0 ? .green : .red)
                        .font(.subheadline)
                    }
                }
                .padding(.bottom, 8)
                
                // Price Chart
                if let historicalData = data.historicalData, !historicalData.isEmpty {
                    Chart {
                        ForEach(historicalData) { point in
                            LineMark(
                                x: .value("Date", point.plottableDate),
                                y: .value("Price", point.price)
                            )
                            .foregroundStyle(.blue)
                            
                            AreaMark(
                                x: .value("Date", point.plottableDate),
                                y: .value("Price", point.price)
                            )
                            .foregroundStyle(.blue.opacity(0.1))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 14)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month().day())
                                .font(.system(size: 8))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel("$\(value.as(Double.self)?.formatted() ?? "")")
                                .font(.system(size: 8))
                        }
                    }
                    .frame(height: 100)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
            }
        }
        .onAppear {
            fetchPriceData()
        }
    }
    
    private func fetchPriceData() {
        isLoading = true
        error = nil
        
        TrackerAPIService.shared.fetchAssetPrice(symbol: symbol) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let data):
                    self.priceData = data
                case .failure(let apiError):
                    self.error = apiError.localizedDescription
                }
            }
        }
    }
}

struct AssetPriceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AssetPriceView(symbol: "AAPL")
        }
    }
} 