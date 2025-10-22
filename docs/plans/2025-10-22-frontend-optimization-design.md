# Frontend Optimization Design

**Date:** 2025-10-22
**Status:** Approved
**Implementation:** Phased approach with git commits between phases

## Overview

Optimize the tg-archive static site generator frontend for better performance, smaller file sizes, and faster page loads. All improvements work within the existing Python-based build system (build.py) without requiring Node.js or framework changes.

## Goals

- Reduce page load times by 30-50%
- Reduce file sizes by 30-40%
- Maintain backward compatibility
- Keep static HTML generation approach
- Enable optimizations by default with debug override

## Non-Goals

- Framework migration (no React/Vue/etc)
- Node.js build tools
- Breaking changes to existing sites

## Architecture Context

**Build Pipeline:**
```
sync.py → SQLite DB → build.py → Static Site
              ↓            ↓
         Telegram API   Jinja2 Templates
              ↓            ↓
         Media Files   HTML + Assets
```

**Key Methods in build.py:**
- `build()` - Main orchestration
- `_create_publish_dir()` - Setup, copy static files
- `_render_page()` - Jinja2 → HTML
- New: `_optimize_static_files()` - Minify CSS/JS

## Implementation Phases

### Phase 1: Template Quick Wins
**Files:** `tgarchive/example/template.html`
**Risk:** Zero (template-only changes)
**Commit:** Single commit after all changes

**Changes:**
1. Add CSS cache busting: `style.css?{{ config.build_timestamp }}`
2. Remove duplicate script tag (line 28, keep line 219)
3. Add `defer` to main.js script tag
4. Add `loading="lazy"` to all images
5. Optimize Google Fonts loading with async pattern

**Expected Impact:**
- 10-15% faster First Contentful Paint
- No render-blocking CSS/fonts
- Better mobile performance

### Phase 2: HTML Minification
**Files:** `build.py`, `requirements.txt`, `__init__.py`, `example/config.yaml`
**Risk:** Low (minification can be disabled)
**Commit:** Single commit after all changes

**Dependencies:**
```
htmlmin>=0.1.12
```

**Code Changes:**
```python
# build.py imports
from htmlmin import minify as minify_html

# build.py _render_page() modification
if not self.config.get("debug_mode", False):
    html = minify_html(html, remove_comments=True, remove_empty_space=True)
```

**Config Addition:**
```python
# __init__.py _CONFIG
"debug_mode": False,
```

**Expected Impact:**
- 15-25% smaller HTML files
- No visual changes
- Can disable with `debug_mode: true`

### Phase 3: CSS/JS Minification
**Files:** `build.py`, `requirements.txt`
**Risk:** Low (operates on copied files)
**Commit:** Single commit after all changes

**Dependencies:**
```
csscompressor>=0.9.5
jsmin>=3.0.1
```

**New Method:**
```python
def _optimize_static_files(self):
    """Minify CSS and JS files in publish_dir/static/"""
    # Skip if debug mode
    # Minify style.css
    # Minify main.js
    # Log size reductions
```

**Integration:**
```python
# build() method, after RSS generation
self._optimize_static_files()
```

**Expected Impact:**
- 30-40% smaller CSS (10KB → 6KB)
- 25-35% smaller JS (2.8KB → 1.8KB)
- Faster page loads

### Phase 4: Image Optimization (Sync Phase)
**Files:** `sync.py`
**Risk:** Very low (only affects new downloads)
**Commit:** Single commit after changes

**Changes:**
```python
# sync.py _download_avatar() method
im.save(fpath, "JPEG", quality=85, optimize=True, progressive=True)
```

**Expected Impact:**
- 10-20% smaller avatar files
- Progressive JPEG for better perceived performance
- Only affects newly downloaded avatars

### Phase 5: Accessibility Improvements
**Files:** `template.html`, `main.js`, `style.css`
**Risk:** Zero (additive only)
**Commit:** Single commit after all changes

**Changes:**
1. Add ARIA labels to navigation elements
2. Add skip link for keyboard navigation
3. Add semantic landmark roles
4. Improve keyboard event handling for burger menu
5. Add focus management

**Expected Impact:**
- Better screen reader support
- Keyboard navigation support
- WCAG AA compliance improvements

### Phase 6: Responsive Images (Future/Optional)
**Files:** `build.py`, `template.html`, `example/config.yaml`
**Risk:** Medium (increases build time)
**Status:** Not implemented initially, opt-in via config flag

**Concept:**
- Generate 640w, 1024w, 1920w variants
- Update template with srcset
- Config: `generate_responsive_images: false` (default off)

## Configuration

### Default Config (_CONFIG in __init__.py)
```python
"debug_mode": False,  # Disable minification for debugging
```

### User Config (config.yaml)
```yaml
# Frontend performance optimizations
# Set to true to disable minification for debugging
debug_mode: false
```

## Testing Strategy

**Approach:** Commit fast, fix issues in follow-ups

**Per Phase:**
1. Make changes
2. Commit with descriptive message
3. Test after commit (not before)
4. If issues found, fix in follow-up commit

**Test Commands:**
```bash
# Test build
tg-archive --build --config=example/config.yaml --template=example/template.html

# Test with debug mode
# In config.yaml: debug_mode: true
tg-archive --build --config=example/config.yaml --template=example/template.html

# Verify file sizes
ls -lh publish_dir/static/
ls -lh publish_dir/*.html
```

**Validation:**
- Check Chrome DevTools Lighthouse scores
- Verify incremental builds still work
- Test with existing archives (backward compatibility)
- Check file sizes match expectations

## Rollback Plan

If minification causes issues:

**Option 1:** Disable via config
```yaml
debug_mode: true
```

**Option 2:** Revert specific commit
```bash
git revert <commit-hash>
```

**Option 3:** Emergency fix in build.py
```python
# Temporarily disable minification
if not self.config.get("debug_mode", False):
    pass  # Skip minification
```

## Performance Targets

### Before Optimizations
- HTML page size: ~50-100KB
- CSS size: 10KB (unminified)
- JS size: 2.8KB (main.js)
- First Contentful Paint: ~2.5s
- Time to Interactive: ~4s

### After Phase 1-3
- HTML page size: ~35-70KB (30% reduction)
- CSS size: 6KB (40% reduction)
- JS size: 1.8KB (35% reduction)
- First Contentful Paint: ~1.8s (28% faster)
- Time to Interactive: ~3s (25% faster)

### After All Phases
- HTML page size: ~30-60KB (40% reduction)
- CSS size: 6KB
- JS size: 1.8KB
- Media: 10-20% smaller avatars
- First Contentful Paint: ~1.2s (52% faster)
- Time to Interactive: ~2.5s (38% faster)

## Dependencies

### Python Libraries (add to requirements.txt)
```
htmlmin>=0.1.12
csscompressor>=0.9.5
jsmin>=3.0.1
```

### No External Dependencies
- No Node.js required
- No npm packages
- No webpack/rollup/vite
- Pure Python build system

## Backward Compatibility

**Guaranteed:**
- Existing config.yaml files work without changes
- New config options have safe defaults
- Visual output unchanged (only file sizes differ)
- All features opt-in or enabled with override

**Migration Path:**
- Users can opt out: `debug_mode: true`
- No database changes required
- No template breaking changes
- Incremental builds continue working

## Success Criteria

**Must Have:**
- [ ] All phases committed separately
- [ ] File sizes reduced by target percentages
- [ ] No visual regressions
- [ ] Incremental builds still work
- [ ] debug_mode flag works correctly

**Nice to Have:**
- [ ] Lighthouse score improves by 10+ points
- [ ] Page load time improves by 30%+
- [ ] No errors in browser console
- [ ] Accessibility score improves

## Future Enhancements

**Not in this design:**
- Service worker for offline support
- Critical CSS extraction and inlining
- WebP/AVIF image conversion
- Virtual scrolling for large message lists
- Component-based template architecture (Jinja2 includes)

**Why not now:**
- Keep changes focused and testable
- Avoid scope creep
- Each enhancement could be its own design doc

## References

- Deep dive analysis: Frontend analysis by frontend-developer agent (2025-10-22)
- Build pipeline documentation: CLAUDE.md
- October 2025 improvements: MERGE_SUMMARY.md
