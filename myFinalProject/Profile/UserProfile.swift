//
//  UserProfile.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//
import Foundation

struct UserProfile {
  var firstName: String
  var lastName: String
  var username: String
  var location: String
  var genderPresentation: String
  var photoURL: String?

  init(firstName: String = "",
       lastName: String = "",
       username: String = "",
       location: String = "",
       genderPresentation: String = "",
       photoURL: String? = nil)
  {
    self.firstName = firstName
    self.lastName  = lastName
    self.username  = username
    self.location  = location
    self.genderPresentation = genderPresentation
    self.photoURL  = photoURL
  }

  init?(dict: [String:Any]) {
    guard let fn = dict["firstName"] as? String,
          let ln = dict["lastName"]  as? String,
          let un = dict["username"]  as? String,
          let lo = dict["location"]  as? String,
          let gp = dict["genderPresentation"] as? String
    else { return nil }
    self.firstName = fn
    self.lastName  = ln
    self.username  = un
    self.location  = lo
    self.genderPresentation = gp
    self.photoURL     = dict["photoURL"] as? String
  }

  func toDict() -> [String:Any] {
    var d: [String:Any] = [
      "firstName": firstName,
      "lastName":  lastName,
      "username":  username,
      "location":  location,
      "genderPresentation": genderPresentation
    ]
    if let url = photoURL {
      d["photoURL"] = url
    }
    return d
  }
}
