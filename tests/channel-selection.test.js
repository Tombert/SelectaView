const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const test = require("node:test");

const mainSceneSource = readFileSync("components/MainScene/MainScene.brs", "utf8");

function currentGroupedSelection(sectionCounts, sectionIndex, listIndex) {
  return listIndex >= 0 && listIndex < sectionCounts[sectionIndex] ? listIndex : -1;
}

function expectedGroupedSelection(sectionCounts, sectionIndex, listIndex) {
  const previousChannelCount = sectionCounts
    .slice(0, sectionIndex)
    .reduce((total, count) => total + count, 0);
  const sectionIndexFromFlatList = listIndex - previousChannelCount;

  if (
    sectionIndexFromFlatList >= 0 &&
    sectionIndexFromFlatList < sectionCounts[sectionIndex]
  ) {
    return sectionIndexFromFlatList;
  }

  return currentGroupedSelection(sectionCounts, sectionIndex, listIndex);
}

test("current grouped lookup cannot select the first channel in the second category", () => {
  const grizzSectionCounts = [20, 13];

  assert.equal(currentGroupedSelection(grizzSectionCounts, 1, 20), -1);
  assert.equal(expectedGroupedSelection(grizzSectionCounts, 1, 20), 0);
});

test("channel selection uses a shared grouped-list resolver", () => {
  const selectorMatch = mainSceneSource.match(
    /sub selectChannelFromList\(list as Object\)[\s\S]*?end sub/
  );

  assert.ok(selectorMatch, "selectChannelFromList should exist");
  assert.match(
    mainSceneSource,
    /function getChannelFromListItem\(list as Object, itemIndex as Integer\) as Object/
  );
  assert.match(
    selectorMatch[0],
    /content = getChannelFromListItem\(list, list\.itemSelected\)/
  );
  assert.doesNotMatch(selectorMatch[0], /sectionContent\.getChild\(itemSelected\)/);
});

test("preview focus uses the same grouped-list resolver as selection", () => {
  const focusHelperMatch = mainSceneSource.match(
    /function getChannelByFocusIndex\(focusIndex as Integer\) as Object[\s\S]*?end function/
  );

  assert.ok(focusHelperMatch, "getChannelByFocusIndex should exist");
  assert.match(
    focusHelperMatch[0],
    /return getChannelFromListItem\(m\.channelList, focusIndex\)/
  );
});
