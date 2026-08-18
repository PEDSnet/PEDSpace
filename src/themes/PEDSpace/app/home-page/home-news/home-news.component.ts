import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { environment } from 'src/environments/environment';
import { HomeNewsComponent as BaseComponent } from '../../../../../app/home-page/home-news/home-news.component';

@Component({
  selector: 'ds-themed-home-news',
  styleUrls: ['./home-news.component.scss'],
  templateUrl: './home-news.component.html',
  standalone: true,
  imports: [CommonModule],
})
export class HomeNewsComponent extends BaseComponent implements OnInit {
  isProduction: boolean = environment.production;
  ipAddressMatch = false;
  showMessageAtAll: boolean = false;

  private targetIpAddress = 'pedsnet.org';

  // objectPosition is cropped to the right so it includes both the doctor and the patient
  heroBubbleImage = {
    path: 'assets/PEDSpace/images/stock_images/kid_with_stripedShirt_CROPPED.jpeg',
    alt: 'A pediatrician checking in with a young patient.',
    objectPosition: 'right center',
  };

  ngOnInit(): void {
    this.ipAddressMatch = (environment.rest.host === this.targetIpAddress);
  }
}
