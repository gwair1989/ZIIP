//
//  TreatmentsListViewController.swift
//  ZIIP
//
//  Created by Zac White on 7/7/20.
//  Copyright © 2020 Velos Mobile LLC. All rights reserved.
//

import Foundation
import UIKit
import Combiner
import Combine
import Rswift
import Kingfisher

class TreatmentsListViewController: CombinerViewController<TreatmentsListCombiner> {

    static let filterHeaderKind = "featuredHeaderKind"
    static let treatmentsHeaderKind = "treatmentsHeaderKind"
    static let pageControlFooterKind = "pageControlFooterKind"
    static let noResultsHeaderKind = "noResultsHeaderKind"

    private enum Constants {
        static let interitemSpacingSmall: CGFloat = 10
        static let interitemSpacingMedium: CGFloat = 20
        static let topSpacingSmall: CGFloat = 0
        static let topSpacingMedium: CGFloat = 30
        static let interitemSpacingLarge: CGFloat = 50
        static let horizontalPaddingCompact: CGFloat = 25
        static let horizontalPaddingRegular: CGFloat = 35
        static let estimatedHeight: CGFloat = 300
        static let fractionalWidth: CGFloat = 0.85
        static let constantCellWidth: CGFloat = 550
        static let constantCellHeight: CGFloat = 350
    }

    private enum Section: Int, CaseIterable {
        case carousel
        case treatmentsGrid
    }

    private enum TreatmentItem: Equatable, Hashable {
        case featured(FeaturedTreatment)
        case treatment(Treatment)
    }

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.alwaysBounceVertical = true
            collectionView.register(R.nib.filterHeaderReusableView, forSupplementaryViewOfKind: Self.filterHeaderKind)
            collectionView.register(R.nib.treatmentsHeaderReusableView, forSupplementaryViewOfKind: Self.treatmentsHeaderKind)
            collectionView.register(R.nib.pageControlReusableView, forSupplementaryViewOfKind: Self.pageControlFooterKind)
            collectionView.register(R.nib.noResultsReusableView, forSupplementaryViewOfKind: Self.noResultsHeaderKind)
        }
    }

    @IBOutlet weak var retryView: UIView!
    @IBOutlet weak var retryButton: UIButton!

    @IBOutlet weak var filterHeaderView: FilterHeaderView!
    @IBOutlet weak var treatmentsView: TreatmentsHeaderView!

    private var currentPageControlView: PageControlReusableView?
    private var currentNoResultsView: UIView?

    private lazy var dataSource: UICollectionViewDiffableDataSource<Section, TreatmentItem> = {
        let dataSource = SkeletonDiffableDataSource<Section, TreatmentItem>(
            collectionView: self.collectionView,
            cellProvider: { collectionView, indexPath, treatmentItem in

                switch treatmentItem {
                case .featured(let featuredTreatment):
                    guard let featuredCell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.featuredTreatmentCell, for: indexPath), let treatment = featuredTreatment.treatment else {
                        return nil
                    }

                    featuredCell.nameLabel.text = treatment.name.localizedUppercase
                    featuredCell.durationLabel.text = treatment.duration
                    featuredCell.featuredLabel.text = featuredTreatment.label.localizedUppercase
                    featuredCell.intensityLabel.text = String(treatment.intensity)

                    switch min(max(treatment.intensity, 1), 3) {
                    case 1:
                        featuredCell.intensityImageView.image = R.image.intensity_1()
                    case 2:
                        featuredCell.intensityImageView.image = R.image.intensity_2()
                    case 3:
                        featuredCell.intensityImageView.image = R.image.intensity_3()
                    default:
                        featuredCell.intensityImageView.image = nil
                    }

                    featuredCell.imageView.kf.cancelDownloadTask()
                    featuredCell.imageView.kf.setImage(with: treatment.imageUrl)

                    return featuredCell

                case .treatment(let treatment):
                    guard let treatmentCell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.treatmentCell, for: indexPath) else {
                        return nil
                    }

                    treatmentCell.nameLabel.text = treatment.name.localizedUppercase
                    treatmentCell.descriptionLabel.text = treatment.caption.trimmingCharacters(in: .whitespacesAndNewlines)
                    treatmentCell.durationLabel.text = treatment.duration
                    treatmentCell.intensityLabel.text = String(treatment.intensity)

                    switch min(max(treatment.intensity, 1), 3) {
                    case 1:
                        treatmentCell.intensityImageView.image = R.image.intensity_1()
                    case 2:
                        treatmentCell.intensityImageView.image = R.image.intensity_2()
                    case 3:
                        treatmentCell.intensityImageView.image = R.image.intensity_3()
                    default:
                        treatmentCell.intensityImageView.image = nil
                    }

                    treatmentCell.imageView.kf.cancelDownloadTask()
                    treatmentCell.imageView.kf.setImage(with: treatment.imageUrl)

                    return treatmentCell
                }
            }
        )

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            if kind == Self.filterHeaderKind {
                return self?.filterHeader(in: collectionView, at: indexPath)
            } else if kind == Self.treatmentsHeaderKind {
                return self?.treatmentsHeader(in: collectionView, at: indexPath)
            } else if kind == Self.pageControlFooterKind {
                return self?.pageControl(in: collectionView, at: indexPath)
            } else if kind == Self.noResultsHeaderKind {
                return self?.noResults(in: collectionView, at: indexPath)
            }

            return nil
        }

        dataSource.sectionCount = 2

        dataSource.numberOfItemsPerSection = [
            Section.carousel.rawValue: 2,
            Section.treatmentsGrid.rawValue: 10
        ]

        dataSource.cellIdentifiers = [
            Section.carousel.rawValue: R.reuseIdentifier.featuredTreatmentCell.identifier,
            Section.treatmentsGrid.rawValue: R.reuseIdentifier.treatmentCell.identifier
        ]

        dataSource.supplimentaryIdentifiers = [
            Self.filterHeaderKind: R.reuseIdentifier.filterHeaderView.identifier,
            Self.pageControlFooterKind: R.reuseIdentifier.pageControlFooter.identifier,
            Self.treatmentsHeaderKind: R.reuseIdentifier.treatmentsHeaderReusableView.identifier,
            Self.noResultsHeaderKind: R.reuseIdentifier.noResults.identifier
        ]

        return dataSource
    }()

    private func filterHeader(in collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionReusableView? {
        guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: Self.filterHeaderKind, withReuseIdentifier: R.reuseIdentifier.filterHeaderView, for: indexPath) else {
            return nil
        }

        guard let filterView = self.filterHeaderView, filterView.superview != view else {
            return view
        }

        filterView.removeFromSuperview()
        view.addSubview(filterView)
        filterView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: filterView.leadingAnchor),
            view.topAnchor.constraint(equalTo: filterView.topAnchor),
            filterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        return view
    }

    private func treatmentsHeader(in collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionReusableView? {
        guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: Self.treatmentsHeaderKind, withReuseIdentifier: R.reuseIdentifier.treatmentsHeaderReusableView, for: indexPath) else {
            return nil
        }

        guard let treatmentsView = self.treatmentsView, treatmentsView.superview != view else {
            return view
        }

        treatmentsView.removeFromSuperview()
        view.addSubview(treatmentsView)
        treatmentsView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: treatmentsView.leadingAnchor),
            view.topAnchor.constraint(equalTo: treatmentsView.topAnchor),
            treatmentsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            treatmentsView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        return view
    }

    private func pageControl(in collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionReusableView? {
        guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: Self.pageControlFooterKind, withReuseIdentifier: R.reuseIdentifier.pageControlFooter, for: indexPath) else {
            return nil
        }

        self.currentPageControlView = view

        return view
    }

    private func noResults(in collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionReusableView? {
        guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: Self.noResultsHeaderKind, withReuseIdentifier: R.reuseIdentifier.noResults, for: indexPath) else {
            return nil
        }

        if let combiner = self.combiner {
            view.isHidden = (combiner.currentState.treatments.isEmpty || !combiner.currentState.filteredTreatments.isEmpty)
        }

        self.currentNoResultsView = view

        return view
    }

    private func update(headerView: TreatmentsHeaderView) {
        guard let combiner = self.combiner else { return }

        headerView.showAllButton
            .publisher(for: .touchUpInside)
            .map { _ in .showAll }
            .subscribe(combiner.action)
            .store(in: &cancellables)

        combiner.state
            .prepend(combiner.currentState)
            .map { $0.filteredTreatments.count < $0.treatments.count }
            .removeDuplicates()
            .sink { visible in
                headerView.showAllButton.isHidden = !visible
            }
            .store(in: &cancellables)
    }

    private lazy var layout: UICollectionViewLayout = {
        return UICollectionViewCompositionalLayout { (section, environment) -> NSCollectionLayoutSection? in

            let columns: Int
            let spacing: CGFloat
            let topSpacing: CGFloat
            let horizontalSpacing: CGFloat
            let carouselWidthDimension: NSCollectionLayoutDimension
            let carouselHeightDimension: NSCollectionLayoutDimension
            if environment.traitCollection.horizontalSizeClass == .compact {
                columns = 2
                spacing = Constants.interitemSpacingSmall
                topSpacing = Constants.topSpacingSmall
                horizontalSpacing = Constants.horizontalPaddingCompact
                carouselWidthDimension = .fractionalWidth(Constants.fractionalWidth)
                carouselHeightDimension = .estimated(250)
            } else if environment.container.effectiveContentSize.width > 900 {
                columns = 4
                spacing = Constants.interitemSpacingLarge
                topSpacing = Constants.topSpacingMedium
                horizontalSpacing = Constants.horizontalPaddingRegular
                carouselWidthDimension = .absolute(Constants.constantCellWidth)
                carouselHeightDimension = .absolute(Constants.constantCellHeight)
            } else {
                columns = 3
                spacing = Constants.interitemSpacingMedium
                topSpacing = Constants.topSpacingMedium
                horizontalSpacing = Constants.horizontalPaddingRegular
                carouselWidthDimension = .absolute(Constants.constantCellWidth)
                carouselHeightDimension = .absolute(Constants.constantCellHeight)
            }

            switch section {
            case Section.carousel.rawValue:

                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: carouselHeightDimension
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(
                    widthDimension: carouselWidthDimension,
                    heightDimension: carouselHeightDimension
                )

                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                var section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                section.interGroupSpacing = 0
                section.visibleItemsInvalidationHandler = { [weak self] items, offset, env in
                    self?.updatePageControl(
                        offset: offset.x,
                        width: carouselWidthDimension.isFractionalWidth ?
                            env.container.effectiveContentSize.width * carouselWidthDimension.dimension :
                            carouselWidthDimension.dimension
                    )
                }
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: Constants.topSpacingMedium,
                    leading: 0,
                    bottom: 0,
                    trailing: 0
                )

                let pageControlFooter = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50)),
                    elementKind: Self.pageControlFooterKind,
                    alignment: .bottom
                )

                section.boundarySupplementaryItems = [pageControlFooter]

                return section

            case Section.treatmentsGrid.rawValue:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(Constants.estimatedHeight)
                )

                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(Constants.estimatedHeight)
                )

                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
                group.interItemSpacing = .fixed(spacing)
                group.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: horizontalSpacing,
                    bottom: 0,
                    trailing: horizontalSpacing
                )

                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = spacing

                let filterHeader = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50)),
                    elementKind: Self.filterHeaderKind,
                    alignment: .topLeading,
                    absoluteOffset: CGPoint(x: 0, y: -50)
                )
                filterHeader.extendsBoundary = true
                filterHeader.zIndex = 2
                if #available(iOS 15.0, *) {
                    filterHeader.pinToVisibleBounds = true
                } else {
                    filterHeader.pinToVisibleBounds = false
                }

                let treatmentsHeader = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50)),
                    elementKind: Self.treatmentsHeaderKind,
                    alignment: .topLeading
                )
                treatmentsHeader.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: horizontalSpacing,
                    bottom: 0,
                    trailing: horizontalSpacing
                )
                treatmentsHeader.extendsBoundary = true
                treatmentsHeader.zIndex = 2

                let noResultsHeader = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50)),
                    elementKind: Self.noResultsHeaderKind,
                    alignment: .top,
                    absoluteOffset: CGPoint(x: 0, y: 70)
                )
                noResultsHeader.zIndex = 3

                section.boundarySupplementaryItems = [filterHeader, treatmentsHeader, noResultsHeader]

                return section
            default:
                fatalError("Unhandled section: \(section)")
            }
        }
    }()
    
    private lazy var layoutIfCaruselIsEmpty: UICollectionViewLayout = {
        return UICollectionViewCompositionalLayout { (section, environment) -> NSCollectionLayoutSection? in

            let columns: Int
            let spacing: CGFloat
            let topSpacing: CGFloat
            let horizontalSpacing: CGFloat
            let carouselWidthDimension: NSCollectionLayoutDimension
            let carouselHeightDimension: NSCollectionLayoutDimension
            if environment.traitCollection.horizontalSizeClass == .compact {
                columns = 2
                spacing = Constants.interitemSpacingSmall
                topSpacing = Constants.topSpacingSmall
                horizontalSpacing = Constants.horizontalPaddingCompact
                carouselWidthDimension = .fractionalWidth(Constants.fractionalWidth)
                carouselHeightDimension = .estimated(250)
            } else if environment.container.effectiveContentSize.width > 900 {
                columns = 4
                spacing = Constants.interitemSpacingLarge
                topSpacing = Constants.topSpacingMedium
                horizontalSpacing = Constants.horizontalPaddingRegular
                carouselWidthDimension = .absolute(Constants.constantCellWidth)
                carouselHeightDimension = .absolute(Constants.constantCellHeight)
            } else {
                columns = 3
                spacing = Constants.interitemSpacingMedium
                topSpacing = Constants.topSpacingMedium
                horizontalSpacing = Constants.horizontalPaddingRegular
                carouselWidthDimension = .absolute(Constants.constantCellWidth)
                carouselHeightDimension = .absolute(Constants.constantCellHeight)
            }

                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(Constants.estimatedHeight)
                )

                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(Constants.estimatedHeight)
                )

                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
                group.interItemSpacing = .fixed(spacing)
                group.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: horizontalSpacing,
                    bottom: 0,
                    trailing: horizontalSpacing
                )

                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = spacing

                let filterHeader = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50)),
                    elementKind: Self.filterHeaderKind,
                    alignment: .topLeading,
                    absoluteOffset: CGPoint(x: 0, y: -50)
                )
                filterHeader.extendsBoundary = true
                filterHeader.zIndex = 2
                if #available(iOS 15.0, *) {
                    filterHeader.pinToVisibleBounds = true
                } else {
                    filterHeader.pinToVisibleBounds = false
                }

                let treatmentsHeader = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50)),
                    elementKind: Self.treatmentsHeaderKind,
                    alignment: .topLeading
                )
                treatmentsHeader.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: horizontalSpacing,
                    bottom: 0,
                    trailing: horizontalSpacing
                )
                treatmentsHeader.extendsBoundary = true
                treatmentsHeader.zIndex = 0

                let noResultsHeader = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50)),
                    elementKind: Self.noResultsHeaderKind,
                    alignment: .top,
                    absoluteOffset: CGPoint(x: 0, y: 70)
                )
                noResultsHeader.zIndex = 3

                section.boundarySupplementaryItems = [filterHeader, treatmentsHeader, noResultsHeader]

                return section

        }
    }()
    
    private func updatePageControl(offset: CGFloat, width: CGFloat) {
        currentPageControlView?.pageControl.currentPage = Int(max(0, round(offset / width)))
    }

    private func updatePageControl(count: Int) {
        currentPageControlView?.pageControl.numberOfPages = count
    }

    /// Bind view events to the action stream in this method
    override func bind(combiner: Combiner) {
        // action (View -> Combiner)
        retryButton.publisher(for: .touchUpInside)
            .map { _ in .tryAgain }
            .subscribe(combiner.action)
            .store(in: &cancellables)

        willAppear
            .map { _ in .viewWillAppear }
            .subscribe(combiner.action)
            .store(in: &cancellables)

        filterHeaderView.$selectedFilters
            .removeDuplicates()
            .dropFirst()
            .map { .updateSelectedFilters($0) }
            .subscribe(combiner.action)
            .store(in: &cancellables)

        publisher(for: \.traitCollection)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.setCollectionViewTopInset()
            }
            .store(in: &cancellables)

        treatmentsView.showAllButton.tapPublisher()
            .map { _ in .showAll }
            .subscribe(combiner.action)
            .store(in: &cancellables)

        // state (Combiner -> View)
        combiner.state
            .prepend(combiner.currentState)
            .combineLatest(willAppear)
            .sink { [weak self] state, _ in
                self?.show(state: state)
            }
            .store(in: &cancellables)

        combiner.state
            .prepend(combiner.currentState)
            .map { $0.shouldShowWalkthrough }
            .removeDuplicates()
            .combineLatest(didAppear)
            .sink { [weak self] shouldShow, _ in
                guard shouldShow else {
                    return
                }

                self?.performSegue(withIdentifier: R.segue.treatmentsListViewController.initialWalkthrough, sender: self)
            }
            .store(in: &cancellables)

        combiner.state
            .prepend(combiner.currentState)
            .map { $0.filters }
            .removeDuplicates()
            .combineLatest(willAppear)
            .sink { [weak self] filters, _ in
                self?.filterHeaderView.allFilters = filters
            }
            .store(in: &cancellables)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.setTabBArSelectedTab(.treatment)
        treatmentsView.treatmentsLabel.text = "Treatments"
    }
    
    override func viewDidLoad() {
        self.combiner = TreatmentsListCombiner()
        super.viewDidLoad()

        setCollectionViewTopInset()
        collectionView.collectionViewLayout = layout

        // reload empty view
        var snapshot = NSDiffableDataSourceSnapshot<Section, TreatmentItem>()
        snapshot.appendSections([.carousel])
        snapshot.appendItems([])
        snapshot.appendSections([.treatmentsGrid])
        snapshot.appendItems([])
        dataSource.apply(snapshot)

        configureNavBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        #if CHINA
        #else
        self.tabBarController?.tabBar.isHidden = false
        #endif
    }
    
    private func configureNavBar() {
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = false

        navigationController?.navigationBar.tintColor = .label
        let backImage = R.image.backChevron()?.withAlignmentRectInsets(UIEdgeInsets(top: 0, left: -10, bottom: 0, right: 0))
        navigationController?.navigationBar.backIndicatorImage = backImage
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backImage
    }

    private func setCollectionViewTopInset() {
        // Needed to set vertical spacing around title consistent with other size class changes
//        if traitCollection.horizontalSizeClass == .compact {
            collectionView.contentInset.top = Constants.topSpacingSmall
//        } else {
//            collectionView.contentInset.top = Constants.topSpacingMedium
//        }
    }

    /// Update the view
    private func show(state: TreatmentsListState) {
        // create snapshot
        var snapshot = NSDiffableDataSourceSnapshot<Section, TreatmentItem>()
        snapshot.appendSections([.carousel])
        let carouselItems = state.featuredTreatments.map { TreatmentItem.featured($0) }
        self.updatePageControl(count: carouselItems.count)
        snapshot.appendItems(carouselItems)
        snapshot.appendSections([.treatmentsGrid])
        snapshot.appendItems(state.filteredTreatments.map { .treatment($0) })

        retryView.isHidden = state.loadingError == nil || !state.treatments.isEmpty
        currentNoResultsView?.isHidden = (state.treatments.isEmpty || !state.filteredTreatments.isEmpty)
        collectionView.isHidden = !retryView.isHidden
        treatmentsView.showAllButton.isHidden = state.selectedFilters.isEmpty
        
            filterHeaderView.showLoading()
            collectionView.showAnimatedGradientSkeleton()
            collectionView.isScrollEnabled = false
            
        if !state.isLoading && collectionView.isSkeletonActive {
            dataSource.apply(snapshot, animatingDifferences: false)
            if state.featuredTreatments.isEmpty && collectionView.sk.isSkeletonActive && state.isLoading {
                print("work")
                collectionView.collectionViewLayout.invalidateLayout()
                collectionView.setCollectionViewLayout(layoutIfCaruselIsEmpty, animated: false) { bool in
                    if bool {
                        self.currentPageControlView?.isHidden = true
                        snapshot.deleteSections([.carousel])
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            }
            
            collectionView.hideSkeleton(reloadDataAfter: false, transition: .none)
            filterHeaderView.hideLoading()
            collectionView.isScrollEnabled = true
            
        } else if !state.treatments.isEmpty && !collectionView.isSkeletonActive {
            dataSource.apply(snapshot)
        }

        filterHeaderView.selectedFilters = state.selectedFilters
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if let detailSegue = R.segue.treatmentsListViewController.treatmentDetailsSegue(segue: segue) {

            guard let cell = sender as? UICollectionViewCell,
                let indexPath = collectionView.indexPath(for: cell),
                let treatmentDetailsVC = detailSegue.destination.topViewController as? TreatmentDetailsViewController else {
                return
            }

            combiner?.action.send(.didTapTreatment)

            let item = dataSource.itemIdentifier(for: indexPath)
            let selectedTreatment: Treatment?

            if case let .treatment(treatment) = item {
                selectedTreatment = treatment
            } else if case let .featured(featuredTreatment) = item {
                selectedTreatment = featuredTreatment.treatment
            } else {
                selectedTreatment = nil
            }

            guard let treatment = selectedTreatment else {
                return
            }

            treatmentDetailsVC.combiner = TreatmentDetailsCombiner(treatment: treatment)
            collectionView.deselectItem(at: indexPath, animated: true)

        } else if let welcomeSegue = R.segue.treatmentsListViewController.initialWalkthrough(segue: segue), let combiner = combiner {
            welcomeSegue.destination.dismissPublisher
                .map { .walkthroughShown }
                .subscribe(combiner.action)
                .store(in: &cancellables)
        }
    }
}
