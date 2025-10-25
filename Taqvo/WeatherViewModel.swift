//
//  WeatherViewModel.swift
//  Taqvo
//
//  Created by Assistant on 10/25/25
//

import Foundation
import WeatherKit
import CoreLocation

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var currentWeather: Weather?
    @Published var cityName: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let weatherService = WeatherService.shared
    private let geocoder = CLGeocoder()
    
    func fetchWeather(for location: CLLocation) async {
        print("🌤️ Fetching weather for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch weather
            print("🌤️ Calling WeatherService...")
            let weather = try await weatherService.weather(for: location)
            currentWeather = weather
            print("🌤️ Weather fetched successfully")
            
            // Reverse geocode to get city name
            print("🌤️ Reverse geocoding location...")
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                cityName = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                print("🌤️ City name: \(cityName)")
            }
        } catch {
            errorMessage = "Unable to fetch weather"
            print("🌤️ Weather fetch error: \(error.localizedDescription)")
        }
        
        isLoading = false
        print("🌤️ Weather loading complete. Has weather: \(currentWeather != nil)")
    }
    
    var weatherConditionIcon: String {
        guard let condition = currentWeather?.currentWeather.condition else {
            return "cloud.fill"
        }
        
        switch condition {
        case .clear:
            return "sun.max.fill"
        case .cloudy:
            return "cloud.fill"
        case .mostlyClear:
            return "cloud.sun.fill"
        case .mostlyCloudy:
            return "cloud.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .rain:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .drizzle:
            return "cloud.drizzle.fill"
        case .snow:
            return "cloud.snow.fill"
        case .sleet:
            return "cloud.sleet.fill"
        case .hail:
            return "cloud.hail.fill"
        case .thunderstorms:
            return "cloud.bolt.rain.fill"
        case .windy:
            return "wind"
        case .foggy:
            return "cloud.fog.fill"
        default:
            return "cloud.fill"
        }
    }
    
    var weatherConditionText: String {
        guard let condition = currentWeather?.currentWeather.condition else {
            return "Loading..."
        }
        
        switch condition {
        case .clear:
            return "Clear"
        case .cloudy:
            return "Cloudy"
        case .mostlyClear:
            return "Mostly Clear"
        case .mostlyCloudy:
            return "Mostly Cloudy"
        case .partlyCloudy:
            return "Partly Cloudy"
        case .rain:
            return "Rain"
        case .heavyRain:
            return "Heavy Rain"
        case .drizzle:
            return "Drizzle"
        case .snow:
            return "Snow"
        case .sleet:
            return "Sleet"
        case .hail:
            return "Hail"
        case .thunderstorms:
            return "Thunderstorms"
        case .windy:
            return "Windy"
        case .foggy:
            return "Foggy"
        default:
            return condition.description
        }
    }
    
    var temperatureCelsius: Int? {
        guard let temp = currentWeather?.currentWeather.temperature else {
            return nil
        }
        return Int(temp.value)
    }
    
    var formattedWeatherString: String {
        guard let temp = temperatureCelsius else {
            return "\(cityName) • Loading..."
        }
        return "\(cityName) • \(weatherConditionText) \(temp)°"
    }
}
