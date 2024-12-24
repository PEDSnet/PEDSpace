package org.dspace.ctask.general;

import java.io.IOException;
import java.sql.SQLException;
import java.util.List;

import org.apache.commons.lang3.StringUtils;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.dspace.content.DSpaceObject;
import org.dspace.content.Item;
import org.dspace.content.MetadataValue;
import org.dspace.content.factory.ContentServiceFactory;
import org.dspace.content.service.ItemService;
import org.dspace.core.Context;
import org.dspace.curate.AbstractCurationTask;
import org.dspace.curate.Curator;
import org.dspace.curate.Distributive;

/**
 * A curation task that copies hierarchical subject terms from "dc.subject"
 * to "local.subject.flat" by extracting only the last node of the hierarchy.
 *
 * Example:
 *   "Top::Mid::Leaf"
 *
 * This task will extract "Leaf" and store it in "local.subject.flat".
 * If an item already contains a local.subject.flat value identical
 * to the extracted one, it won't be duplicated.
 *
 * Similar to BasicLinkChecker, this task returns SKIP for non-Item objects,
 * allowing it to be run site-wide (e.g. handle [handle-prefix]/0) while
 * only processing actual items.
 */
@Distributive
public class CopyHierarchicalSubjectsToFlat extends AbstractCurationTask {

    /** Logger for this class */
    private static final Logger log = LogManager.getLogger(CopyHierarchicalSubjectsToFlat.class);

    /** The curation status for this task. Defaults to UNSET until we decide what to do. */
    private int status = Curator.CURATE_UNSET;

    /** Used to access metadata on Items. */
    private final ItemService itemService = ContentServiceFactory.getInstance().getItemService();

    /**
     * Perform the curation task upon a DSpaceObject. Will skip if it's
     * not an Item. If it is an Item, we'll copy hierarchical subject
     * terms from "dc.subject" into "local.subject.flat".
     *
     * @param dso The DSpaceObject (likely Item, but could be Site/Community/Collection)
     * @return The final curation status (SKIP, SUCCESS, FAIL)
     * @throws IOException if an error occurs
     */
    @Override
    public int perform(DSpaceObject dso) throws IOException {

        // We'll keep track of details in a StringBuilder, which we pass to setResult() at the end.
        StringBuilder sb = new StringBuilder();

        // Start by assuming we skip (like BasicLinkChecker). If we find an Item, we do more.
        status = Curator.CURATE_SKIP;

        if (dso instanceof Item) {
            Item item = (Item) dso;
            sb.append("Item: ").append(getItemHandle(item)).append("\n");

            // Attempt to get a curation context (some tasks need it for writing changes).
            Context context;
            try {
                context = Curator.curationContext();
            } catch (SQLException e) {
                log.error("Unable to obtain curation Context for Item: {}", getItemHandle(item), e);
                throw new IOException("Could not get curation context", e);
            }

            // Retrieve dc.subject fields
            List<MetadataValue> subjects = itemService.getMetadata(item, "dc", "subject", null, Item.ANY);

            // If no dc.subject, we consider that scenario specifically
            if (subjects.isEmpty()) {
                sb.append("No dc.subject values present. Skipping.\n");
                log.info("Item {} has no dc.subject - skipping processing.", getItemHandle(item));
                // status remains SKIP, no further processing is done
            } else {
                // Retrieve existing local.subject.flat fields to avoid duplicates
                List<MetadataValue> existingFlats =
                    itemService.getMetadata(item, "local", "subject", "flat", Item.ANY);

                // We'll track whether we actually changed anything
                boolean modified = false;

                // Process each subject
                for (MetadataValue mv : subjects) {
                    String originalValue = mv.getValue();
                    if (StringUtils.isBlank(originalValue)) {
                        continue; // skip empties
                    }

                    String extracted = extractLastNode(originalValue);
                    log.debug("Extracted '{}' from originalValue: '{}'", extracted, originalValue);

                    // Check if we already have that flat subject
                    boolean alreadyHas = existingFlats.stream()
                            .anyMatch(val -> val.getValue().equals(extracted));
                    if (alreadyHas) {
                        sb.append("   Subject '").append(extracted).append("' already exists.\n");
                    } else {
                        // Attempt to add it
                        try {
                            itemService.addMetadata(context, item, "local", "subject", "flat", null, extracted);
                            sb.append("   Added '").append(extracted).append("' to local.subject.flat.\n");
                            log.info("Added local.subject.flat value '{}' to item {}",
                                     extracted, getItemHandle(item));
                            modified = true;
                        } catch (SQLException e) {
                            log.error("Error adding local.subject.flat to item: {}",
                                      getItemHandle(item), e);
                            throw new IOException("Error adding local.subject.flat", e);
                        }
                    }
                }

                // If we changed something, commit to database & set success
                if (modified) {
                    try {
                        itemService.update(context, item);
                        sb.append("   -> Changes saved.\n");
                        log.info("Updated item {} with new local.subject.flat values.",
                                 getItemHandle(item));
                    } catch (SQLException e) {
                        log.error("Error updating item: {}", getItemHandle(item), e);
                        throw new IOException("Error updating item", e);
                    }
                    status = Curator.CURATE_SUCCESS;
                } else {
                    sb.append("No new local.subject.flat values added.\n");
                    status = Curator.CURATE_SUCCESS;
                }
            }
        } else {
            // Not an item, so we skip. This allows running on the entire site
            // without error for non-Item objects (like the "Site" object).
            sb.append("Skipping non-Item object.\n");
        }

        // Provide the final result text
        setResult(sb.toString());
        // BasicLinkChecker calls report(...) so we do the same
        report(sb.toString());

        return status;
    }

    /**
     * Extract the final node after the last "::" separator. If no "::"
     * is found, returns the original value as is.
     *
     * @param val The hierarchical subject string
     * @return The extracted leaf node
     */
    private String extractLastNode(String val) {
        int idx = val.lastIndexOf("::");
        if (idx >= 0 && idx < val.length() - 2) {
            return val.substring(idx + 2).trim();
        }
        return val.trim();
    }

    /**
     * Get a user-friendly descriptor of the item's handle. If handle is
     * null, assume it's in workflow.
     *
     * @param item The Item whose handle we want
     * @return The handle or " in workflow" if null
     */
    private String getItemHandle(Item item) {
        String handle = item.getHandle();
        return (handle != null) ? handle : " in workflow";
    }
}
