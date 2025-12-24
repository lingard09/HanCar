//
//  LoginViewController.swift
//  hancar
//
//  Created by kinnwonjin on 12/10/25.
//
//  This view controller handles user authentication using Google Sign-In.
//  It restricts login to Handong University accounts (@handong.ac.kr)
//  and signs the user into Firebase Authentication before navigating
//  to the main screen.
//

import UIKit
import GoogleSignIn
import FirebaseCore
import FirebaseAuth

class LoginViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func didTapGoogleLogin(_ sender: UIButton) {
        signInWithGoogle()
    }
    
    // MARK: - Google Sign-In
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            return
        }

        GIDSignIn.sharedInstance.configuration =
            GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(
            withPresenting: self
        ) { result, error in

            if error != nil {
                return
            }

            guard let result = result else { return }
            let user = result.user

            guard let email = user.profile?.email else {
                return
            }
            
            // Allow only Handong University accounts
            if !email.hasSuffix("@handong.ac.kr") {

                GIDSignIn.sharedInstance.signOut()

                self.showDomainErrorAlert()
                return
            }

            guard let idToken = user.idToken?.tokenString else {
                return
            }

            let accessToken = user.accessToken.tokenString

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            Auth.auth().signIn(with: credential) { _, error in
                if error != nil {
                    return
                }
                self.goToMainScreen()
            }
        }
    }
    
    // MARK: - Alert
    func showDomainErrorAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Cannot login",
                message: "Only allow ~~~@handong.ac.kr",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Confirm", style: .default))
            self.present(alert, animated: true)
        }
    }

    // MARK: - Navigation
    func goToMainScreen() {
        DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let mainVC = storyboard.instantiateViewController(
                withIdentifier: "MainViewController"
            )

            mainVC.modalPresentationStyle = .fullScreen
            self.present(mainVC, animated: true)
        }
    }
}
