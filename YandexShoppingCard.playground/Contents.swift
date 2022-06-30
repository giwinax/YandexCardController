import UIKit
import Foundation
import PlaygroundSupport
// MARK: - FOOD STRUCT
struct Food: Codable {
    var id: String
    var name: String?
    var description: String?
    var price: Double
    var imageURL: String
    init(name: String?, description: String?, price: Double, image: String) {
        self.id = ""
        self.name = name
        self.description = description
        self.price = price
        self.imageURL = image
    }
}
// MARK: - FOOD SERVICE
class FoodService: NSObject {

    static var shared: FoodService {
        FoodService()
    }

    func loadFood(page: Int) -> [Food] {
        var result = [Food]()
        URLSession.shared.dataTask(with: URL(string: "http://food.example.com/list?page=\(page)")!) { (data, response, error) in
            if let data = data {
                let decoder = JSONDecoder()
                result += try! decoder.decode([Food].self, from: data)
            }
        }.resume()
        return result
    }

    func buyFood(cart: [Food?], completion: @escaping (Bool) -> Void = { _ in }) {
        let semaphore = DispatchSemaphore(value: 0)
        let firstURL = URL(string: "http://food.example.com/prepare_buy")!
        var firstURLRequest = URLRequest(url: firstURL)
        firstURLRequest.httpMethod = "POST"
        URLSession.shared.dataTask(with: firstURLRequest) { _, _, _ in
            semaphore.signal()
        }.resume()
        semaphore.wait()

        var unwrappedCartArray: [Food] = []
        for cartItem in cart {
            if let item = cartItem {
                unwrappedCartArray.append(item)
            }
        }
        var parameters: [String: Int] = [:]
        for element in unwrappedCartArray {
            if parameters[element.id] != nil {
                parameters[element.id] = (parameters[element.id] ?? 0) + 1
                continue
            }
            parameters[element.id] = 1
        }

        let secondURL = URL(string: "http://food.example.com/confirm_buy")!
        var secondURLRequest = URLRequest(url: secondURL)
        secondURLRequest.httpMethod = "POST"
        secondURLRequest.httpBody = try! JSONSerialization.data(withJSONObject: parameters)
        URLSession.shared.dataTask(with: secondURLRequest) { _, _, error in
            completion(error == nil)
        }.resume()
    }

}
// MARK: - FOOD VIEW CONTROLLER
class FoodViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var foodTableView = UITableView(frame: CGRect(x: 0, y: 0, width: 0, height: 0), style: .plain)
    var buyButton: UIButton!

    var list: [Food] = []
    var cart: [Food?] = []
    var currentPage = 0
    var pageSize = 0
    
    let backgroundQueue = DispatchQueue.global(qos: .background)

    override func viewDidLoad() {
        buyButton = UIButton(frame: .zero)
        view.addSubview(buyButton)
        view.addSubview(foodTableView)
        foodTableView.frame = view.bounds
        buyButton.frame = CGRect(x: 24, y: view.bounds.height - 80, width: view.bounds.width - 48, height: 40)
        buyButton.layer.cornerRadius = buyButton.frame.size.height / 2
        buyButton.setTitle("Buy", for: .normal)
        buyButton.addTarget(self, action: #selector(buy), for: .touchUpOutside)
        buyButton.isHidden = true
        foodTableView.delegate = self
        foodTableView.dataSource = self
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        backgroundQueue.async {
            let page = FoodService.shared.loadFood(page: 0)
            self.list.append(contentsOf: page)
            self.pageSize = page.count
            DispatchQueue.main.sync {
                self.foodTableView.reloadData()
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (currentPage + 1) * pageSize
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let foodCell = cell as! FoodCell
        foodCell.data = list[indexPath.row]
        if indexPath.row == list.count - 1 {
            list.append(contentsOf: FoodService.shared.loadFood(page: currentPage))
            currentPage += 1
            tableView.reloadData()
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let element = list[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: element.name ?? "")!
        (cell as? FoodCell)?.reloadData()
        return cell
    }

    func addToCart(cell: FoodCell) {
        cart.append(cell.data)
        buyButton.isHidden = cart.isEmpty
    }

    @objc private func buy() {
        buyButton.isUserInteractionEnabled = false
        FoodService.shared.buyFood(cart: cart) { [buyButton] isError in
            buyButton?.isUserInteractionEnabled = true
            if isError {
                // надо показать ошибку
            }
        }
    }
}
// MARK: - FOOD VIEW CELL
class FoodCell: UITableViewCell {

    @IBOutlet var imgView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var priceLabel: UILabel!

    var foodViewController: FoodViewController?

    var data: Food?
    var tapAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadData() {
        guard let data = data else { return }
        URLSession.shared.dataTask(with: URL(string: data.imageURL)!) { data, _, _ in
            guard let data = data else { return }
            self.nameLabel?.text = self.data?.name
            self.priceLabel?.text = "\(self.data?.price ?? 0) ₽"
            self.imgView?.image = UIImage(data: data)
        }.resume()
    }

    @objc func tap() {
        foodViewController?.addToCart(cell: self)
    }

}
// MARK: - PLAYGROUND SUPPORT
let master = FoodViewController()
let nav = UINavigationController(rootViewController: master)
PlaygroundPage.current.liveView = nav
