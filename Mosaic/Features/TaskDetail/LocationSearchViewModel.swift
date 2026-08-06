import Foundation
@preconcurrency import MapKit

struct ResolvedPlace: Equatable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

@Observable
@MainActor
final class LocationSearchViewModel: NSObject {
    var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    private(set) var results: [MKLocalSearchCompletion] = []
    private(set) var errorMessage: String?

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> ResolvedPlace? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(), let item = response.mapItems.first else {
            errorMessage = "Couldn't find that place."
            return nil
        }
        return ResolvedPlace(
            name: item.name ?? completion.title,
            address: item.placemark.title ?? completion.subtitle,
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude
        )
    }
}

extension LocationSearchViewModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "Couldn't search for that place."
        }
    }
}
