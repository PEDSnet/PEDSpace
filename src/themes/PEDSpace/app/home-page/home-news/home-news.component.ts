import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { ThemedHomeNewsComponent } from 'src/app/home-page/home-news/themed-home-news.component';
import { environment } from 'src/environments/environment';
import { HomeNewsComponent as BaseComponent } from '../../../../../app/home-page/home-news/home-news.component';

// Import CoreUI components
import {
  CarouselComponent,
  CarouselInnerComponent,
  CarouselItemComponent
} from '@coreui/angular';

@Component({
  selector: 'ds-themed-home-news',
  styleUrls: ['./home-news.component.scss'],
  templateUrl: './home-news.component.html',
  standalone: true,
  imports: [
    BaseComponent, 
    CommonModule, 
    ThemedHomeNewsComponent,
    CarouselComponent,
    CarouselInnerComponent,
    CarouselItemComponent
  ],
})
export class HomeNewsComponent extends BaseComponent implements OnInit {
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
      position: 'center 90%'
    },
    {
      path: 'assets/PEDSpace/images/stock_images/kid_with_toy_car.jpg',
      alt: 'Child holding toy car',
      credit: 'RDNE Stock project',
      showCredit: true,
      position: 'center 10%'
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
  
  // Track the current active image for credits
  currentImageIndex = 0;

  constructor() {
    super();
  }

  ngOnInit(): void {
    this.ipAddressMatch = (environment.rest.host === this.targetIpAddress);
  }
  
  // Event handler for when carousel changes items
  onItemChange(index: number): void {
    this.currentImageIndex = index;
  }
  
  // Get the currently active image
  get activeImage() {
    return this.images[this.currentImageIndex];
  }
}