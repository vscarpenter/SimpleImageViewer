// AI.swift
// Lightweight facade for AI-related types and services during namespacing migration

import Foundation

// Namespace facade for AI features
public enum AI {}

public extension AI {
    // Namespaced model type alias (was: AIModel)
    typealias Model = AIImageAnalysisService.Model
    
    // Ergonomic access to the shared AI service
    static var service: AIImageAnalysisService { AIImageAnalysisService.shared }
}
