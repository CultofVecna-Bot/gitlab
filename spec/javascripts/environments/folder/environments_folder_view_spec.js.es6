const Vue = require('vue');
require('~/flash');
const EnvironmentsFolderViewComponent = require('~/environments/folder/environments_folder_view');
const { environmentsList } = require('../mock_data');

describe('Environments Folder View', () => {
  preloadFixtures('static/environments/environments_folder_view.html.raw');

  beforeEach(() => {
    loadFixtures('static/environments/environments_folder_view.html.raw');
    window.history.pushState({}, null, 'environments/folders/build');
  });

  let component;

  describe('successfull request', () => {
    const environmentsResponseInterceptor = (request, next) => {
      next(request.respondWith(JSON.stringify({
        environments: environmentsList,
        stopped_count: 1,
        available_count: 0,
      }), {
        status: 200,
        headers: {
          'X-nExt-pAge': '2',
          'x-page': '1',
          'X-Per-Page': '1',
          'X-Prev-Page': '',
          'X-TOTAL': '37',
          'X-Total-Pages': '2',
        },
      }));
    };

    beforeEach(() => {
      Vue.http.interceptors.push(environmentsResponseInterceptor);
      component = new EnvironmentsFolderViewComponent({
        el: document.querySelector('#environments-folder-list-view'),
      });
    });

    afterEach(() => {
      Vue.http.interceptors = _.without(
        Vue.http.interceptors, environmentsResponseInterceptor,
      );
    });

    it('should render a table with environments', (done) => {
      setTimeout(() => {
        expect(
          component.$el.querySelectorAll('table tbody tr').length,
        ).toEqual(2);
        done();
      }, 0);
    });

    it('should render available tab with count', (done) => {
      setTimeout(() => {
        expect(
          component.$el.querySelector('.js-available-environments-folder-tab').textContent,
        ).toContain('Available');

        expect(
          component.$el.querySelector('.js-available-environments-folder-tab .js-available-environments-count').textContent,
        ).toContain('0');
        done();
      }, 0);
    });

    it('should render stopped tab with count', (done) => {
      setTimeout(() => {
        expect(
          component.$el.querySelector('.js-stopped-environments-folder-tab').textContent,
        ).toContain('Stopped');

        expect(
          component.$el.querySelector('.js-stopped-environments-folder-tab .js-stopped-environments-count').textContent,
        ).toContain('1');
        done();
      }, 0);
    });

    it('should render parent folder name', (done) => {
      setTimeout(() => {
        expect(
          component.$el.querySelector('.js-folder-name').textContent,
        ).toContain('Environments / build');
        done();
      }, 0);
    });

    describe('pagination', () => {
      it('should render pagination', (done) => {
        setTimeout(() => {
          expect(
            component.$el.querySelectorAll('.gl-pagination li').length,
          ).toEqual(5);
          done();
        }, 0);
      });

      it('should update url when no search params are present', (done) => {
        spyOn(gl.utils, 'visitUrl');
        setTimeout(() => {
          component.$el.querySelector('.gl-pagination li:nth-child(5) a').click();
          expect(gl.utils.visitUrl).toHaveBeenCalledWith('?page=2');
          done();
        }, 0);
      });

      it('should update url when page is already present', (done) => {
        spyOn(gl.utils, 'visitUrl');
        window.history.pushState({}, null, '?page=1');

        setTimeout(() => {
          component.$el.querySelector('.gl-pagination li:nth-child(5) a').click();
          expect(gl.utils.visitUrl).toHaveBeenCalledWith('?page=2');
          done();
        }, 0);
      });

      it('should update url when page and scope are already present', (done) => {
        spyOn(gl.utils, 'visitUrl');
        window.history.pushState({}, null, '?scope=all&page=1');

        setTimeout(() => {
          component.$el.querySelector('.gl-pagination li:nth-child(5) a').click();
          expect(gl.utils.visitUrl).toHaveBeenCalledWith('?scope=all&page=2');
          done();
        }, 0);
      });

      it('should update url when page and scope are already present and page is first param', (done) => {
        spyOn(gl.utils, 'visitUrl');
        window.history.pushState({}, null, '?page=1&scope=all');

        setTimeout(() => {
          component.$el.querySelector('.gl-pagination li:nth-child(5) a').click();
          expect(gl.utils.visitUrl).toHaveBeenCalledWith('?page=2&scope=all');
          done();
        }, 0);
      });
    });
  });

  describe('unsuccessfull request', () => {
    const environmentsErrorResponseInterceptor = (request, next) => {
      next(request.respondWith(JSON.stringify([]), {
        status: 500,
      }));
    };

    beforeEach(() => {
      Vue.http.interceptors.push(environmentsErrorResponseInterceptor);
    });

    afterEach(() => {
      Vue.http.interceptors = _.without(
        Vue.http.interceptors, environmentsErrorResponseInterceptor,
      );
    });

    it('should not render a table', (done) => {
      component = new EnvironmentsFolderViewComponent({
        el: document.querySelector('#environments-folder-list-view'),
      });

      setTimeout(() => {
        expect(
          component.$el.querySelector('table'),
        ).toBe(null);
        done();
      }, 0);
    });

    it('should render available tab with count 0', (done) => {
      setTimeout(() => {
        expect(
          component.$el.querySelector('.js-available-environments-folder-tab').textContent,
        ).toContain('Available');

        expect(
          component.$el.querySelector('.js-available-environments-folder-tab .js-available-environments-count').textContent,
        ).toContain('0');
        done();
      }, 0);
    });

    it('should render stopped tab with count 0', (done) => {
      setTimeout(() => {
        expect(
          component.$el.querySelector('.js-stopped-environments-folder-tab').textContent,
        ).toContain('Stopped');

        expect(
          component.$el.querySelector('.js-stopped-environments-folder-tab .js-stopped-environments-count').textContent,
        ).toContain('0');
        done();
      }, 0);
    });
  });
});
