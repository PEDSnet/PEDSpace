import { CommonModule } from '@angular/common';
import {
  Component,
  OnInit,
  OnDestroy,
  NgZone,
  ApplicationRef,
  ChangeDetectorRef
} from '@angular/core';
import { ThemedHomeNewsComponent } from 'src/app/home-page/home-news/themed-home-news.component';
import { environment } from 'src/environments/environment';

// eslint-disable-next-line dspace-angular-ts/themed-component-usages
import { HomeNewsComponent as BaseComponent } from '../../../../../app/home-page/home-news/home-news.component';

@Component({
  selector: 'ds-themed-home-news',
  styleUrls: ['./home-news.component.scss'],
  templateUrl: './home-news.component.html',
  standalone: true,
  imports: [BaseComponent, CommonModule, ThemedHomeNewsComponent],
})
export class HomeNewsComponent extends BaseComponent implements OnInit, OnDestroy {
  isProduction: boolean = environment.production;
  ipAddressMatch = false;
  showDevOnProdMessage = false;
  showMessageAtAll: boolean = false;

  private targetIpAddress = 'pedsnetapps.chop.edu';

  // Original images array with position properties
  private originalImages = [
    {
      path: 'assets/PEDSpace/images/dandy-full.jpg',
      alt: 'Dandelion',
      credit: 'inspiredimages',
      showCredit: true,
      position: 'center bottom' // Dandelion showing more of the bottom
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_toy_car.jpg',
      alt: 'Child holding toy car',
      credit: 'RDNE Stock project',
      showCredit: true,
      position: 'center 5%' // Focus more on the child's face
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_bandaid.jpg',
      alt: 'Child with bandaid',
      showCredit: false,
      position: 'center 30%' // Focus on the upper part of image
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_necklace.jpg',
      alt: 'Child with necklace',
      showCredit: false,
      position: 'center 45%' // Focus slightly higher than center
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_stethoscope.jpg',
      alt: 'Child with stethoscope',
      showCredit: false,
      position: 'center 20%' // Focus on the child with stethoscope
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_yellowShirt.jpg',
      alt: 'Child with yellow shirt',
      showCredit: false,
      position: 'center 35%' // Center position
    }
  ];

  // Randomized array for the current session
  images: any[] = [];
  currentImageIndex = 0;
  private carouselInterval: any;
  preloadedImages: HTMLImageElement[] = [];

  constructor(
    private ngZone: NgZone,
    private appRef: ApplicationRef,
    private cdr: ChangeDetectorRef
  ) {
    super();
  }

  ngOnInit(): void {
    this.ipAddressMatch = (environment.rest.host === this.targetIpAddress);
    
    // Randomize the images array
    this.randomizeImages();
    
    // Preload all images to avoid flicker
    this.preloadImages();
    
    // Start with a shorter interval for testing
    setTimeout(() => {
      this.nextImage();
    }, 5000); // First change after 5 seconds for quick testing
  }
  
  ngOnDestroy(): void {
    this.stopCarousel();
  }
  
  // Fisher-Yates shuffle algorithm to randomize images array
  randomizeImages(): void {
    // Create a copy of the original array
    this.images = [...this.originalImages];
    
    // Shuffle the array
    for (let i = this.images.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.images[i], this.images[j]] = [this.images[j], this.images[i]];
    }
  }
  
  preloadImages(): void {
    // Preload all images
    this.images.forEach(image => {
      const img = new Image();
      img.src = image.path;
      this.preloadedImages.push(img);
    });
  }
  
  nextImage(): void {
    // Update the image index
    this.currentImageIndex = (this.currentImageIndex + 1) % this.images.length;
    
    // Force view update
    this.cdr.detectChanges();
    this.appRef.tick();
    
    // Schedule the next update
    this.carouselInterval = setTimeout(() => {
      this.nextImage();
    }, 15000); // Regular 15 second interval after first change
  }
  
  stopCarousel(): void {
    if (this.carouselInterval) {
      clearTimeout(this.carouselInterval);
    }
  }
  
  get currentImage() {
    return this.images[this.currentImageIndex];
  }
}