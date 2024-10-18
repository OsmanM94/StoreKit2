
import SwiftUI
import StoreKit

struct StoreKitView: View {
    @Environment(StoreKitViewModel.self) private var viewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                switch viewModel.productViewState {
                case .empty:
                    ContentUnavailableView("Empty", systemImage: "tray.fill")
                    
                case .loading:
                    ProgressView()
                        .scaleEffect(1.2)
                    
                case .loaded:
                    productView
                    
                case .error(let message):
                    errorView(message)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.productViewState)
            .navigationTitle("Shop")
            .sheet(item: Bindable(viewModel).selectedProduct) { product in
                ProductDetailView(product: product)
                    .interactiveDismissDisabled(viewModel.purchaseViewState == .purchasing)
                    .presentationDragIndicator(.visible)
            }
        }
        .task {
            await viewModel.loadProducts()
        }
    }
    
    private var productView: some View {
        List {
            ForEach(viewModel.products, id: \.id) { product in
                ProductRow(product: product, isUnlocked: viewModel.unlockedFeatures[product.id] ?? false) {
                    viewModel.selectedProduct = product
                }
            }
        }
    }
    
    private func errorView(_ message: String) -> some View  {
        ContentUnavailableView {
            Label("\(message)", systemImage: "xmark.icloud.fill")
        } description: {
            Text("")
        } actions: {
            Button {
                Task {
                    await viewModel.loadProducts()
                }
            } label: {
                Text("Try again")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

fileprivate struct ProductRow: View {
    let product: Product
    let isUnlocked: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .font(.headline)
                
                Text(product.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(action: action) {
                    Text("View")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding(.vertical, 8)
    }
}

fileprivate struct ProductDetailView: View {
    @Environment(StoreKitViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let product: Product
    
    var body: some View {
        VStack(spacing: 20) {
            switch viewModel.purchaseViewState {
            case .ready:
                readyView
                
            case .purchasing:
                storeKitProgressView
                
            case .completed:
                completedView
                
            case .failed(let message):
                failedView(error: message)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.purchaseViewState)
        .padding()
    }
    
    private var productImage: some View {
        Image(viewModel.imageNameForProduct(product))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .containerRelativeFrame(.horizontal)
    }

    private var readyView: some View {
        VStack(spacing: 20) {
            productImage
                
            Text(product.displayName)
                .font(.title)
                .fontDesign(.rounded)
            
            Text(product.displayPrice)
                .font(.headline)
            
            Button(action: {
                Task {
                    await viewModel.purchase(product: product)
                }
            }) {
                Text("Purchase")
            }
            .buttonStyle(.bordered)
            .controlSize(.extraLarge)
            .disabled(viewModel.purchaseViewState == .purchasing)
        }
    }
    
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 50))
            
            Text("Purchase successful!")
                .font(.title2)
                .fontWeight(.bold)
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .fontDesign(.rounded)
        .padding()
    }
    
    private func failedView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.gray)
                .font(.system(size: 50))
            
            Text("Purchase Failed")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await viewModel.purchase(product: product)
                    dismiss()
                }
            }) {
                Text("Try Again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.purchaseViewState == .purchasing)
        }
        .fontDesign(.rounded)
        .padding()
    }
    
    private var storeKitProgressView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Processing your purchase...")
                .font(.headline)
        }
        .fontDesign(.rounded)
        .padding()
    }
}

#Preview {
    StoreKitView()
        .environment(StoreKitViewModel())
}
