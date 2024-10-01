import { Component, OnInit } from '@angular/core';
import { environment } from 'src/environments/environment';
import { CommonModule } from '@angular/common';
import { HomeNewsComponent as BaseComponent } from '../../../../../app/home-page/home-news/home-news.component';

@Component({
  selector: 'ds-themed-home-news',
  styleUrls: ['./home-news.component.scss'],
  templateUrl: './home-news.component.html',
  standalone: true,
  imports: [BaseComponent, CommonModule],
})
export class HomeNewsComponent extends BaseComponent implements OnInit {
  isProduction: boolean = environment.production; 
  ipAddressMatch: boolean = false; // For storing if IP matches
  showDevOnProdMessage: boolean = false;

  private targetIpAddress = 'pedsdspaceprod.research.chop.edu'; // Production IP

  constructor() {
    super();
  }

  ngOnInit(): void {
    // Check if the environment's host matches the target IP
    this.ipAddressMatch = (environment.rest.host === this.targetIpAddress);
  }
}
