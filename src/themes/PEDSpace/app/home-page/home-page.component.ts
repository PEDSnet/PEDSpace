import {
  AsyncPipe,
  NgClass,
  NgFor,
  NgIf,
  NgTemplateOutlet,
} from '@angular/common';
import { Component, OnInit, OnDestroy, NgZone, ChangeDetectorRef, Inject } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { NgbDropdownModule } from '@ng-bootstrap/ng-bootstrap';
import { APP_CONFIG, AppConfig } from 'src/config/app-config.interface';
import { TranslateModule } from '@ngx-translate/core';

import { ThemedCommunityListPageComponent } from 'src/app/community-list-page/themed-community-list-page.component';
import { HomeCoarComponent } from '../../../../app/home-page/home-coar/home-coar.component';
import { ThemedHomeNewsComponent } from '../../../../app/home-page/home-news/themed-home-news.component';
import { HomePageComponent as BaseComponent } from '../../../../app/home-page/home-page.component';
import { RecentItemListComponent } from '../../../../app/home-page/recent-item-list/recent-item-list.component';
import { ThemedTopLevelCommunityListComponent } from '../../../../app/home-page/top-level-community-list/themed-top-level-community-list.component';
import { SuggestionsPopupComponent } from '../../../../app/notifications/suggestions-popup/suggestions-popup.component';
import { ThemedConfigurationSearchPageComponent } from '../../../../app/search-page/themed-configuration-search-page.component';
import { ThemedSearchFormComponent } from '../../../../app/shared/search-form/themed-search-form.component';
import { PageWithSidebarComponent } from '../../../../app/shared/sidebar/page-with-sidebar.component';

@Component({
  selector: 'ds-themed-home-page',
  styleUrls: ['./home-page.component.scss'],
  templateUrl: './home-page.component.html',
  standalone: true,
  imports: [ThemedHomeNewsComponent, ThemedCommunityListPageComponent, NgTemplateOutlet, NgIf, NgFor, NgClass, RouterLink, ThemedSearchFormComponent, ThemedTopLevelCommunityListComponent, RecentItemListComponent, AsyncPipe, TranslateModule, SuggestionsPopupComponent, ThemedConfigurationSearchPageComponent, PageWithSidebarComponent, HomeCoarComponent, NgbDropdownModule],
})
export class HomePageComponent extends BaseComponent implements OnInit, OnDestroy {
  carouselIndex = 0;
  private carouselTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(
    @Inject(APP_CONFIG) appConfig: AppConfig,
    route: ActivatedRoute,
    private ngZone: NgZone,
    private cdr: ChangeDetectorRef,
  ) {
    super(appConfig, route);
  }

  carouselImages = [
    { path: 'assets/PEDSpace/images/dandy-full.jpg', alt: 'Dandelion' },
    { path: 'assets/PEDSpace/images/stock_images/kid_with_stripedShirt_CROPPED.jpeg', alt: 'Child speaking with a pediatrician.' },
    { path: 'assets/PEDSpace/images/stock_images/kid_with_stethoscope_CROPPED.jpg', alt: 'A child receiving a stethoscope reading.' },
    { path: 'assets/PEDSpace/images/stock_images/three_kids_chillin_CROPPED.jpg', alt: 'Three children sitting together.' },
    { path: 'assets/PEDSpace/images/stock_images/children_on_bike.jpg', alt: 'Three children riding bikes.' },
  ];

  override ngOnInit(): void {
    super.ngOnInit();
    this.scheduleNext();
  }

  ngOnDestroy(): void {
    if (this.carouselTimer) {
      clearTimeout(this.carouselTimer);
    }
  }

  private scheduleNext(): void {
    this.ngZone.runOutsideAngular(() => {
      this.carouselTimer = setTimeout(() => {
        this.ngZone.run(() => {
          this.carouselIndex = (this.carouselIndex + 1) % this.carouselImages.length;
          this.cdr.detectChanges();
          this.scheduleNext();
        });
      }, 7500);
    });
  }

  nextCarouselImage(): void {
    if (this.carouselTimer) { clearTimeout(this.carouselTimer); }
    this.carouselIndex = (this.carouselIndex + 1) % this.carouselImages.length;
    this.scheduleNext();
  }

  prevCarouselImage(): void {
    if (this.carouselTimer) { clearTimeout(this.carouselTimer); }
    this.carouselIndex = (this.carouselIndex - 1 + this.carouselImages.length) % this.carouselImages.length;
    this.scheduleNext();
  }
}
