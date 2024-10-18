
import Foundation
import StoreKit

enum PurchaseViewState: Equatable {
    case ready
    case purchasing
    case completed
    case failed(String)
}

enum LoadingProductsViewState: Equatable {
    case empty
    case loading
    case loaded
    case error(String)
}

enum StoreError: Error {
    case failedVerification
    case productNotAvailable
    case purchaseFailed(underlying: Error)
    case networkError
    case userCancelled
    case unknownError
    
    var localizedDescription: String {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotAvailable:
            return "Product is not available"
        case .purchaseFailed(let error):
            return "Purchase failed: \(error)"
        case .networkError:
            return "Network error occurred"
        case .userCancelled:
            return "Purchase was cancelled by the user"
        case .unknownError:
            return "An unknown error occurred, try again."
        }
    }
}

@Observable
final class StoreKitViewModel {
    var products: [Product] = []
    var selectedProduct: Product?
    let productNames = ["adjustments", "template2", "template3", "template4"]
    
    var purchaseViewState: PurchaseViewState = .ready
    var productViewState: LoadingProductsViewState = .loading
    
    var unlockedFeatures: [String: Bool] = [
        "adjustments": false,
        "template2": false,
        "template3": false,
        "template4": false
    ] {
        didSet {
            saveUnlockedFeatures()
        }
    }
    
    private var transactionListener: Task<Void, Error>?
    
    init() {
        loadUnlockedFeatures()
        transactionListener = configureTransactionListener()
        Task {
            await checkForExistingPurchases()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Methods
    
    @MainActor
    func purchase(product: Product) async {
        do {
            purchaseViewState = .purchasing
            let result = try await product.purchase()
            try await handlePurchase(from: result, for: product)
        } catch {
            purchaseViewState = .failed(StoreError.purchaseFailed(underlying: error).localizedDescription)
        }
    }
    
    @MainActor
    func loadProducts() async {
        do {
            let products = try await Product.products(for: productNames)
            self.products = sortProductsByCustomOrder(products)
            
            purchaseViewState = .ready
            productViewState = products.isEmpty ? .empty : .loaded
        } catch {
            productViewState = .error(StoreError.unknownError.localizedDescription)
        }
    }
    
    func imageNameForProduct(_ product: Product) -> String {
       switch product.id {
           case "adjustments": return "adjustments_image"
           case "template2": return "template2"
           case "template3": return "template3"
           case "template4": return "template4"
           default: return "default_product_image"
       }
   }
    
    // MARK: - Private methods
    
    private func configureTransactionListener() -> Task<Void, Error> {
        Task { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await self?.updatePurchaseState(for: transaction?.productID)
                    self?.purchaseViewState = .completed
                    
                    await transaction?.finish()
                } catch {
                    self?.purchaseViewState = .failed(StoreError.failedVerification.localizedDescription)
                }
            }
        }
    }
    
    @MainActor
    private func handlePurchase(from result: Product.PurchaseResult, for product: Product) async throws {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchaseState(for: product.id)
            purchaseViewState = .completed
            await transaction.finish()
            
        case .pending:
            purchaseViewState = .purchasing
            
        case .userCancelled:
            purchaseViewState = .ready
            
        @unknown default:
            purchaseViewState = .failed("DEBUG: What the heck just happened...?")
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
            
        case .verified(let safe):
            return safe
        }
    }
    
    @MainActor
    private func updatePurchaseState(for productID: String?) async {
        guard let productID = productID else { return }
        unlockedFeatures[productID] = true
    }
    
    @MainActor
    private func checkForExistingPurchases() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                await updatePurchaseState(for: transaction.productID)
            }
        }
    }
    
    private func saveUnlockedFeatures() {
        if let encoded = try? JSONEncoder().encode(unlockedFeatures) {
            UserDefaults.standard.set(encoded, forKey: "UnlockedFeatures")
        }
    }
    
    private func loadUnlockedFeatures() {
        if let savedFeatures = UserDefaults.standard.object(forKey: "UnlockedFeatures") as? Data,
           let decodedFeatures = try? JSONDecoder().decode([String: Bool].self, from: savedFeatures) {
            unlockedFeatures = decodedFeatures
        }
    }
    
    private func sortProductsByCustomOrder(_ products: [Product]) -> [Product] {
        return products.sorted { productOrder(for: $0) < productOrder(for: $1) }
    }
    
    private func productOrder(for product: Product) -> Int {
        switch product.id {
        case "adjustments": return 0
        case "template2": return 1
        case "template3": return 2
        case "template4": return 3
        default: return 4
        }
    }
}

