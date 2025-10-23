(function() {
	// Initialize lazy loading for media with lozad
	if (typeof lozad !== 'undefined') {
		const observer = lozad('.lozad', {
			loaded: function(el) {
				el.classList.add('loaded');
			}
		});
		observer.observe();
	}

	// Image Modal/Lightbox functionality
	function initImageModal() {
		// Create modal element
		const modal = document.createElement('div');
		modal.className = 'image-modal';
		modal.setAttribute('role', 'dialog');
		modal.setAttribute('aria-label', 'Image viewer');

		const closeBtn = document.createElement('button');
		closeBtn.className = 'close-modal';
		closeBtn.textContent = '×';  // Safe: using textContent instead of innerHTML
		closeBtn.setAttribute('aria-label', 'Close image viewer');

		const img = document.createElement('img');
		img.alt = 'Full size image';

		modal.appendChild(closeBtn);
		modal.appendChild(img);
		document.body.appendChild(modal);

		// Open modal when clicking images
		document.addEventListener('click', (e) => {
			// Only handle image clicks in .media containers, not thumbnails
			if (e.target.tagName === 'IMG' &&
			    e.target.closest('.messages .media') &&
			    !e.target.classList.contains('thumb') &&
			    e.target.hasAttribute('data-src')) {
				e.preventDefault();

				// Use data-src for lazy loaded images, fallback to src
				const imgSrc = e.target.getAttribute('data-src') || e.target.src;
				img.src = imgSrc;
				img.alt = e.target.getAttribute('title') || 'Full size image';
				modal.classList.add('active');
				document.body.style.overflow = 'hidden'; // Prevent background scrolling
			}
		});

		// Close modal functions
		function closeModal() {
			modal.classList.remove('active');
			document.body.style.overflow = ''; // Restore scrolling
			img.src = ''; // Clear image to save memory
		}

		// Close on button click
		closeBtn.addEventListener('click', closeModal);

		// Close on background click
		modal.addEventListener('click', (e) => {
			if (e.target === modal) {
				closeModal();
			}
		});

		// Close on ESC key
		document.addEventListener('keydown', (e) => {
			if (e.key === 'Escape' && modal.classList.contains('active')) {
				closeModal();
			}
		});
	}

	// Initialize image modal
	initImageModal();

	// Hide the open burger menu when clicking nav links.
	const burger = document.querySelector("#burger");
	document.querySelectorAll(".timeline a, .dayline a").forEach((e) => {
		e.onclick = (event) => {
			burger.checked = false;

			// Handle anchor navigation on same page
			const href = e.getAttribute('href');
			const hashIndex = href.indexOf('#');

			if (hashIndex !== -1) {
				const targetFile = href.substring(0, hashIndex);
				const targetHash = href.substring(hashIndex + 1);
				const currentFile = window.location.pathname.split('/').pop().split('#')[0];

				// If clicking anchor on same page, prevent default and smooth scroll
				if (targetFile === currentFile || targetFile === '') {
					event.preventDefault();
					const targetElement = document.getElementById(targetHash);

					if (targetElement) {
						targetElement.scrollIntoView({
							behavior: 'smooth',
							block: 'start'
						});

						// Update URL hash without triggering scroll
						history.pushState(null, null, `#${targetHash}`);

						// Update selected state in dayline
						updateDaylineSelection(targetHash);
					}
				}
			}
		};
	});

	// Handle hash on page load
	window.addEventListener('load', () => {
		if (window.location.hash) {
			const hash = window.location.hash.substring(1);
			const targetElement = document.getElementById(hash);

			if (targetElement) {
				// Small delay to ensure page is fully rendered
				setTimeout(() => {
					targetElement.scrollIntoView({
						behavior: 'smooth',
						block: 'start'
					});
					updateDaylineSelection(hash);
				}, 100);
			}
		}
	});

	// Helper function to update dayline selection
	function updateDaylineSelection(targetHash) {
		const selected = document.querySelector(".dayline .selected");
		if (selected) {
			selected.classList.remove("selected");
		}
		const daylineItem = document.querySelector(`.dayline .day-${targetHash}`);
		if (daylineItem) {
			daylineItem.classList.add("selected");
		}
	}

	// Change page anchor on scrolling past days.
	let scrollTimeout = null;
	document.addEventListener('scroll', () => {
		if (scrollTimeout) {
			window.clearTimeout(scrollTimeout);
		}
		scrollTimeout = window.setTimeout(() => {
			const days = document.querySelectorAll(".messages .day");
			let lastID = days[0]?.id;

			days.forEach((el) => {
				if (el.getBoundingClientRect().top < 100) {
					lastID = el.id;
				}
			});

			if (lastID) {
				history.replaceState({}, "", `#${lastID}`);
				updateDaylineSelection(lastID);
			}
		}, 100);
	});
})();
