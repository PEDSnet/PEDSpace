import { CommonModule } from '@angular/common';
import {
  Component,
  OnInit,
  OnDestroy,
  NgZone, 
  ChangeDetectorRef
} from '@angular/core';
import { ThemedHomeNewsComponent } from 'src/app/home-page/home-news/themed-home-news.component';
import { environment } from 'src/environments/environment';
import { HomeNewsComponent as BaseComponent } from '../../../../../app/home-page/home-news/home-news.component';

@Component({
  selector: 'ds-themed-home-news',
  styleUrls: ['./home-news.component.scss'],
  templateUrl: './home-news.component.html',
  standalone: true,
  imports: [
    BaseComponent, 
    CommonModule, 
    ThemedHomeNewsComponent
  ],
})
export class HomeNewsComponent extends BaseComponent implements OnInit, OnDestroy {
  isProduction: boolean = environment.production;
  ipAddressMatch = false;
  showMessageAtAll: boolean = false;

  private targetIpAddress = 'pedsnetapps.chop.edu';
  
  // Image array 
  images = [
    {
      path: 'assets/PEDSpace/images/dandy-full.jpg',
      alt: 'Dandelion',
      credit: 'inspiredimages',
      showCredit: true,
      position: 'center bottom'
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_stripedShirt_CROPPED.jpeg',
      alt: 'Child speaking with a pediatrician on bed.',
      showCredit: false,
      position: 'right'
    },
    // {
    //   path: 'assets/PEDSpace/images/stock_images/kid_with_bandaid_CROPPED.jpg',
    //   alt: 'A child receiving a band-aid.',
    //   showCredit: false,
    //   position: 'right 30%'
    // },
    // {
    //   path: 'assets/PEDSpace/images/stock_images/kid_with_necklace_CROPPED.jpeg',
    //   alt: 'A teenager speaking with a pediatrician.',
    //   showCredit: false,
    //   position: 'right'
    // },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_stethoscope_CROPPED.jpg',
      alt: 'A child receiving a stethoscope reading with their mother',
      showCredit: false,
      position: 'right'
    },
    // {
    //   path: 'assets/PEDSpace/images/stock_images/kid_with_yellowShirt.jpg',
    //   alt: 'A child receiving a stethoscope reading with his mother.',
    //   showCredit: false,
    //   position: 'right center'
    // },
    {
      path: 'assets/PEDSpace/images/stock_images/three_kids_chillin_CROPPED.jpg',
      alt: 'Three children sitting closely together.',
      showCredit: false,
      position: 'center'
    }
  ];
  
  currentImageIndex = 0;
  private carouselTimer: any;
  private visibilityChangeListener: any;

  constructor(
    private ngZone: NgZone, 
    private cdr: ChangeDetectorRef
  ) {
    super();
  }

  ngOnInit(): void {
    this.ipAddressMatch = (environment.rest.host === this.targetIpAddress);
    
    // Preload images
    this.preloadImages();
    
    // Start carousel
    this.startCarousel();
    
    // Set up visibility change listener
    this.setupVisibilityListener();
  }
  
  ngOnDestroy(): void {
    if (this.carouselTimer) {
      clearTimeout(this.carouselTimer);
    }
    
    // Remove visibility listener
    if (this.visibilityChangeListener) {
      document.removeEventListener('visibilitychange', this.visibilityChangeListener);
    }
  }
  
  // Setup visibility change listener to pause/resume carousel when tab is inactive/active
  setupVisibilityListener(): void {
    this.visibilityChangeListener = () => {
      if (document.hidden) {
        // Tab is hidden, clear the timer
        if (this.carouselTimer) {
          clearTimeout(this.carouselTimer);
          this.carouselTimer = null;
        }
      } else {
        // Tab is visible again, restart the carousel
        if (!this.carouselTimer) {
          this.startCarousel();
        }
      }
    };
    
    document.addEventListener('visibilitychange', this.visibilityChangeListener);
  }
  
  // Preload all images for smoother transitions
  preloadImages(): void {
    this.images.forEach(image => {
      const img = new Image();
      img.src = image.path;
    });
  }
  
  // Start the carousel timer
  startCarousel(): void {
    // Run outside Angular zone for better performance
    this.ngZone.runOutsideAngular(() => {
      this.carouselTimer = setTimeout(() => {
        // Run change detection inside Angular zone
        this.ngZone.run(() => {
          this.nextImage();
        });
      }, 15000);
    });
  }
  
  // Move to next image
  nextImage(): void {
    this.currentImageIndex = (this.currentImageIndex + 1) % this.images.length;
    
    // Force change detection
    this.cdr.detectChanges();
    
    // Schedule next transition
    this.startCarousel();
  }
  
  get activeImage() {
    return this.images[this.currentImageIndex];
  }
}