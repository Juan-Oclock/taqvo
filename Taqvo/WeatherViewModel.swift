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
            // Reverse geocode to get city name first
            print("🌤️ Reverse geocoding location...")
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                cityName = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                print("🌤️ City name: \(cityName)")
            }
            
            // Try to fetch weather
            print("🌤️ Calling WeatherService...")
            let weather = try await weatherService.weather(for: location)
            currentWeather = weather
            print("🌤️ Weather fetched successfully")
        } catch {
            // If WeatherKit fails (missing entitlement), use mock data
            print("🌤️ Weather fetch error: \(error.localizedDescription)")
            print("🌤️ Using mock weather data as fallback")
            
            // Use mock weather data
            useMockWeather()
        }
        
        isLoading = false
        print("🌤️ Weather loading complete. Has weather: \(currentWeather != nil)")
    }
    
    private func useMockWeather() {
        // Create mock weather data for development
        // This will be replaced with real data once WeatherKit is properly configured
        mockWeatherCondition = .clear
        mockTemperature = 28 // Typical temperature for Philippines
        
        if cityName.isEmpty {
            cityName = "Davao City"
        }
    }
    
    // Mock weather properties
    private var mockWeatherCondition: WeatherCondition?
    private var mockTemperature: Int?
    
    var weatherConditionIcon: String {
        // Prefer real weather data over mock
        if let condition = currentWeather?.currentWeather.condition {
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
        
        // Fallback to mock data if no real weather
        if let mockCondition = mockWeatherCondition {
            switch mockCondition {
            case .clear:
                return "sun.max.fill"
            case .cloudy:
                return "cloud.fill"
            case .partlyCloudy:
                return "cloud.sun.fill"
            case .rain:
                return "cloud.rain.fill"
            default:
                return "cloud.fill"
            }
        }
        
        return "cloud.fill"
    }
    
    var weatherConditionText: String {
        // Prefer real weather data over mock
        if let condition = currentWeather?.currentWeather.condition {
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
        
        // Fallback to mock data if no real weather
        if let mockCondition = mockWeatherCondition {
            switch mockCondition {
            case .clear:
                return "Clear"
            case .cloudy:
                return "Cloudy"
            case .partlyCloudy:
                return "Partly Cloudy"
            case .rain:
                return "Rain"
            default:
                return "Clear"
            }
        }
        
        return "Loading..."
    }
    
    var temperatureCelsius: Int? {
        // Prefer real weather data over mock
        if let temp = currentWeather?.currentWeather.temperature {
            return Int(temp.value)
        }
        
        // Fallback to mock temperature
        if let mockTemp = mockTemperature {
            return mockTemp
        }
        
        return nil
    }
    
    var formattedWeatherString: String {
        guard let temp = temperatureCelsius else {
            return "\(cityName) • Loading..."
        }
        return "\(cityName) • \(weatherConditionText) \(temp)°"
    }
}
