//
//  ParticleEmitter.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 13.12.25.
//

protocol ParticleEmitting {
    var particleStyle: ParticleStyle { get }
}


enum ParticleStyle {
    case asteroid
    case boss
    case enemy
}

