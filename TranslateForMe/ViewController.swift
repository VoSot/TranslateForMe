import UIKit

class ViewController: UIViewController, UITextViewDelegate {

    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var translateButton: UIButton!
    @IBOutlet weak var outputTextView: UITextView!
    @IBOutlet weak var sourceLanguageLabel: UILabel!
    @IBOutlet weak var targetLanguageLabel: UILabel!

    private var sourceLanguage: String = "English" {
        didSet {
            sourceLanguageLabel.text = sourceLanguage
        }
    }
    private var targetLanguage: String = "Russian" {
        didSet {
            targetLanguageLabel.text = targetLanguage
        }
    }

    private var apiKey: String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let key = config["API_KEY"] as? String else {
            return nil
        }
        return key
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
        configureGestureRecognizers()
        inputTextView.delegate = self
        updateLanguageLabels()
    }

    private func configureNavigationBar() {
        guard let navBar = navigationController?.navigationBar else { return }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()

        appearance.backgroundColor = UIColor(hex: "#7AB2B2")
        appearance.titleTextAttributes = [.foregroundColor: UIColor(hex: "#EEF7FF") ?? .white]

        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = navBar.standardAppearance
    }

    private func configureGestureRecognizers() {
        setupLabelTapGesture(label: sourceLanguageLabel, action: #selector(sourceLanguageLabelTapped))
        setupLabelTapGesture(label: targetLanguageLabel, action: #selector(targetLanguageLabelTapped))
    }

    private func setupLabelTapGesture(label: UILabel, action: Selector) {
        let tapGesture = UITapGestureRecognizer(target: self, action: action)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(tapGesture)
    }

    private func updateLanguageLabels() {
        sourceLanguageLabel.text = sourceLanguage
        targetLanguageLabel.text = targetLanguage
    }

    @IBAction func translateButtonTapped(_ sender: UIButton) {
        guard let text = inputTextView.text, !text.isEmpty else {
            outputTextView.text = "Please enter text to translate."
            return
        }

        toggleTranslateButton(isEnabled: false)
        translateTextWithChatGPT(text)
    }

    private func toggleTranslateButton(isEnabled: Bool) {
        translateButton.isEnabled = isEnabled
        translateButton.setTitle(isEnabled ? "Translate" : "Translating...", for: .normal)
    }

    @objc private func sourceLanguageLabelTapped() {
        showLanguageSelectionPopup(for: .source)
    }

    @objc private func targetLanguageLabelTapped() {
        showLanguageSelectionPopup(for: .target)
    }

    private enum LanguageType {
        case source
        case target
    }

    private func showLanguageSelectionPopup(for languageType: LanguageType) {
        let alertController = UIAlertController(title: "Select Language", message: nil, preferredStyle: .actionSheet)

        let languages = ["English", "Russian", "Spanish", "French", "German"]
        for language in languages {
            alertController.addAction(createLanguageAction(language: language, type: languageType))
        }

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    private func createLanguageAction(language: String, type: LanguageType) -> UIAlertAction {
        let action = UIAlertAction(title: language, style: .default) { [weak self] _ in
            switch type {
            case .source:
                self?.sourceLanguage = language
            case .target:
                self?.targetLanguage = language
            }
        }
        action.setValue(UIColor.black, forKey: "titleTextColor")
        return action
    }

    func translateTextWithChatGPT(_ text: String) {
        guard let apiKey = apiKey else {
            updateOutputText("API key is missing.")
            return
        }

        let urlString = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let messages = [
            ["role": "system", "content": "You are a helpful assistant."],
            ["role": "user", "content": "Translate the following text from \(sourceLanguage) to \(targetLanguage): \(text)"]
        ]

        let parameters: [String: Any] = ["model": "gpt-4", "messages": messages]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: .fragmentsAllowed)

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.toggleTranslateButton(isEnabled: true)
            }

            if let error = error {
                self?.updateOutputText("Translation failed: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                self?.updateOutputText("Translation failed: No data received")
                return
            }

            self?.handleTranslationResponse(data)
        }

        task.resume()
    }

    private func handleTranslationResponse(_ data: Data) {
        do {
            let chatGPTResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
            if let translatedText = chatGPTResponse.choices.first?.message.content {
                updateOutputText(translatedText)
            } else {
                updateOutputText("Translation failed: No content in response")
            }
        } catch {
            updateOutputText("Translation failed: \(error.localizedDescription)")
        }
    }

    private func updateOutputText(_ text: String) {
        DispatchQueue.main.async {
            self.outputTextView.text = text
        }
    }

    struct ChatGPTResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let role: String
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView == inputTextView, textView.text.isEmpty {
            outputTextView.text = ""
        }
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}
