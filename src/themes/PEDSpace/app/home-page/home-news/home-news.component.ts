import { CommonModule } from '@angular/common';
import {
  Component,
  OnInit,
  OnDestroy
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
      path: 'assets/PEDSpace/images/stock_images/kid_with_toy_car.jpg',
      alt: 'Child holding toy car',
      credit: 'RDNE Stock project',
      showCredit: true,
      position: 'center 20%'
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_bandaid.jpg',
      alt: 'Child with bandaid',
      showCredit: false,
      position: 'center 30%'
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_necklace.jpg',
      alt: 'Child with necklace',
      showCredit: false,
      position: 'center 35%'
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_stethoscope.jpg',
      alt: 'Child with stethoscope',
      showCredit: false,
      position: 'center 40%'
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_yellowShirt.jpg',
      alt: 'Child with yellow shirt',
      showCredit: false,
      position: 'center 45%'
    }
  ];
  
  currentImageIndex = 0;
  private carouselTimer: any;

  constructor() {
    super();
  }

  ngOnInit(): void {
    this.ipAddressMatch = (environment.rest.host === this.targetIpAddress);
    
    // Preload images
    this.preloadImages();
    
    // Start carousel
    this.startCarousel();
  }
  
  ngOnDestroy(): void {
    if (this.carouselTimer) {
      clearTimeout(this.carouselTimer);
    }
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
    this.carouselTimer = setTimeout(() => {
      this.nextImage();
    }, 15000);
  }
  
  // Move to next image
  nextImage(): void {
    this.currentImageIndex = (this.currentImageIndex + 1) % this.images.length;
    
    // Schedule next transition
    this.carouselTimer = setTimeout(() => {
      this.nextImage();
    }, 15000);
  }
  
  get activeImage() {
    return this.images[this.currentImageIndex];
  }
}