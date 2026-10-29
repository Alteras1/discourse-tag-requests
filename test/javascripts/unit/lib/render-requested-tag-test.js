import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderRequestedTag from "discourse/plugins/discourse-tag-requests/discourse/lib/render-requested-tag";

module("Unit | Lib | render-requested-tag", function (hooks) {
  setupTest(hooks);

  function render(name, options) {
    const container = document.createElement("div");
    container.innerHTML = renderRequestedTag(name, options);
    return container.firstElementChild;
  }

  test("renders a link styled like a tag", function (assert) {
    const pill = render("rust", { style: "box" });

    assert.strictEqual(pill.tagName, "A", "renders a link by default");
    assert.strictEqual(
      pill.getAttribute("href"),
      "/filter?q=pending-tag%3Arust",
      "links to the pending-tag filter"
    );
    assert.deepEqual(
      [...pill.classList],
      ["discourse-tag", "box", "requested-tag"],
      "uses the tag and site style classes"
    );
  });

  test("renders without a link for other elements", function (assert) {
    const pill = render("rust", { tagName: "span" });

    assert.strictEqual(pill.tagName, "SPAN", "uses the requested element");
    assert.false(pill.hasAttribute("href"), "has no link");
  });

  test("escapes the name", function (assert) {
    const pill = render("<b>rust</b>");

    assert.strictEqual(pill.querySelector("b"), null, "does not inject markup");
    assert.true(
      pill.textContent.includes("<b>rust</b>"),
      "shows the name as text"
    );
  });
});
