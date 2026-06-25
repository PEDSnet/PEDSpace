import { CommonModule } from '@angular/common';
import {
  Component,
  ElementRef,
  OnInit,
} from '@angular/core';
import { RouterModule } from '@angular/router';

@Component({
  selector: 'ds-about-content',
  templateUrl: './about-content.component.html',
  styleUrls: ['./about-content.component.scss'],
  standalone: true,
  imports: [CommonModule, RouterModule],
})
/**
 * Component displaying the content of the PEDSpace Knowledge Bank About page
 */
export class AboutContentComponent implements OnInit {

  constructor(private elementRef: ElementRef) {}

  ngOnInit(): void {
    // Set a random starting position for the hero gradient animation (0-20 seconds)
    const randomStart = Math.random() * 20;
    const heroSection = this.elementRef.nativeElement.querySelector('.hero-section');
    if (heroSection) {
      heroSection.style.setProperty('--random-start', randomStart.toString());
    }
  }
}
