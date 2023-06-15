//
//  ViewController.swift
//  ARNavigator
//
//  Created by Роман Шуркин on 15.06.2023.
//

import UIKit
import MapKit

class ViewController: UIViewController {
	
	private lazy var startButton: UIButton = {
		let btn = UIButton()
		var config = UIButton.Configuration.filled()
		
		let title = NSAttributedString(
			string: "Start",
			attributes: [
				.font: UIFont.preferredFont(forTextStyle: .body)
			]
		)
		config.attributedTitle = AttributedString(
			title
		)
		
		config.baseBackgroundColor = .systemBlue
		config.buttonSize = .large
		config.cornerStyle = .medium
		
		btn.configuration = config
		btn.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
		
		return btn
	}()
	
	private var mapView: StartMapView?
	
	private var arWayView: ARWayView?

	override func viewDidLoad() {
		super.viewDidLoad()
		setUp()
	}
	
	private func setUp() {
		view.backgroundColor = .white
		
		startButton.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(startButton)
		startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
		startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
	}
	
	@objc
	private func startTapped() {
		var config = startButton.configuration
		config?.showsActivityIndicator = true
		config?.title = nil
		startButton.configuration = config
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
			self?.setMapViewState()
			self?.startButton.removeFromSuperview()
		}
	}
	
	private func setMapViewState() {
		self.mapView?.removeFromSuperview()
		
		let mapView = StartMapView()
		
		mapView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(mapView)
		mapView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
		mapView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
		mapView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
		mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

		self.mapView = mapView
	}
}

extension CLLocationCoordinate2D: Equatable {
	public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
		lhs.latitude == rhs.latitude
		&& lhs.longitude == rhs.longitude
	}
}

import Combine

protocol LocationManager {
	var userLocationPublisher: AnyPublisher<CLLocationCoordinate2D, Never> { get }
	func start()
}

final class LocationManagerImpl: NSObject, LocationManager {
	var userLocationPublisher: AnyPublisher<CLLocationCoordinate2D, Never> {
		userLocationSubject.eraseToAnyPublisher()
	}
	
	private let userLocationSubject = PassthroughSubject<CLLocationCoordinate2D, Never>()
	
	private let locationManager: CLLocationManager
	
	override init() {
		self.locationManager = CLLocationManager()
		super.init()
		
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
	}
	
	func start() {
		locationManager.requestWhenInUseAuthorization()
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			if CLLocationManager.locationServicesEnabled() {
				self?.locationManager.startUpdatingLocation()
			}
		}
	}
}

extension LocationManagerImpl: CLLocationManagerDelegate {
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		let userLocation: CLLocation = locations[0] as CLLocation
		userLocationSubject.send(userLocation.coordinate)
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		print("Error - locationManager: \(error.localizedDescription)")
	}
}

final class ARWayView: UIView {
	
}

final class StartMapView: UIView {
	private lazy var getItemsButton: UIButton = {
		let btn = UIButton()
		var config = UIButton.Configuration.filled()
		
		let title = NSAttributedString(
			string: "Найти доступные места",
			attributes: [
				.font: UIFont.preferredFont(forTextStyle: .body)
			]
		)
		config.attributedTitle = AttributedString(
			title
		)
		
		config.baseBackgroundColor = .systemBlue
		config.buttonSize = .large
		config.cornerStyle = .medium
		
		btn.configuration = config
		btn.addTarget(self, action: #selector(getItemsTapped), for: .touchUpInside)
		
		return btn
	}()
	
	private let locationManager: LocationManager = LocationManagerImpl()
	
	private var mapView = MKMapView()
	
	private var currentCoordinate: CLLocationCoordinate2D?
	
	private var cancellable = Set<AnyCancellable>()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setUp()
		bind()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func setUp() {
		locationManager.start()
		
		mapView.delegate = self
		
		mapView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(mapView)
		mapView.topAnchor.constraint(equalTo: topAnchor).isActive = true
		mapView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
		mapView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
		mapView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
		
		getItemsButton.translatesAutoresizingMaskIntoConstraints = false
		addSubview(getItemsButton)
		getItemsButton.leftAnchor.constraint(equalTo: leftAnchor, constant: 20).isActive = true
		getItemsButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -20).isActive = true
		getItemsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -60).isActive = true
	}
	
	private func bind() {
		locationManager.userLocationPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] coordinate in
				self?.setCoordinateToMap(coordinate)
			}
			.store(in: &cancellable)
	}
	
	@objc
	private func getItemsTapped() {
		var config = getItemsButton.configuration
		config?.showsActivityIndicator = true
		config?.title = nil
		getItemsButton.configuration = config
	}
	
	private func setCoordinateToMap(_ coordinate: CLLocationCoordinate2D) {
		guard currentCoordinate != coordinate else {
			return
		}
		
		mapView.showsUserLocation = true
		self.currentCoordinate = coordinate
		
		let mapRegion = MKCoordinateRegion(
			center: coordinate,
			span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
		)
		mapView.setRegion(mapRegion, animated: true)
	}
}

extension StartMapView: MKMapViewDelegate {
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {

		guard !(annotation is MKUserLocation) else {
			return nil
		}

		var view = mapView.dequeueReusableAnnotationView(withIdentifier: "reuseIdentifier") as? MKMarkerAnnotationView
		if view == nil {
			view = MKMarkerAnnotationView(annotation: nil, reuseIdentifier: "reuseIdentifier")
		}
		view?.annotation = annotation
		view?.displayPriority = .required
		return view
	}
}

//class ListViewController: UIViewController {
//
//	var index = 0
//
//	private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout()!)
//
//	override func viewDidLoad() {
//		navigationController?.setNavigationBarHidden(true, animated: true)
//		collectionView.translatesAutoresizingMaskIntoConstraints = false
//		view.addSubview(collectionView)
//
//		collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
//		collectionView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
//		collectionView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
//		collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
//
//		collectionView.dataSource = self
//		collectionView.delegate = self
//
//		if #available(iOS 14.0, *) {
//			collectionView.register(Cell.self, forCellWithReuseIdentifier: "cell")
//		} else {
//			// Fallback on earlier versions
//		}
//	}
//
//	func createLayout() -> UICollectionViewLayout? {
//		if #available(iOS 14.0, *) {
//			var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
//			configuration.showsSeparators = true
//			return UICollectionViewCompositionalLayout.list(using: configuration)
//		} else {
//			return nil
//		}
//	}
//}
//
//extension ListViewController: UICollectionViewDataSource {
//	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//		1
//	}
//
//	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//		if #available(iOS 14.0, *) {
//			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
//
//			return cell
//		} else {
//			// Fallback on earlier versions
//			return UICollectionViewCell()
//		}
//	}
//}

//extension ListViewController: UICollectionViewDelegate {
//	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//		let storyboard = UIStoryboard(name: "Main", bundle: nil)
//		let vc = storyboard.instantiateViewController(withIdentifier: "search")
//		(vc as? SearchSceneViewController)?.route = RouteCacheService.shared.allRoutes()[index]
//		navigationController?.pushViewController(vc, animated: true)
////		performSegue(withIdentifier: "from_home_to_search", sender:  RouteCacheService.shared.allRoutes()[1])
//	}
//}
//
//@available(iOS 14.0, *)
//class Cell: UICollectionViewListCell {
//	override init(frame: CGRect) {
//		super.init(frame: frame)
//		var content = defaultContentConfiguration()
//		content.text = "Деканат"
//		content.textProperties.color = .black
//		contentConfiguration = content
//	}
//
//	required init?(coder: NSCoder) {
//		fatalError("init(coder:) has not been implemented")
//	}
//}

